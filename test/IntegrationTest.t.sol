// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../contracts/SimpleLimitOrderProtocol.sol";
import "../contracts/interfaces/IOrderMixin.sol";
import "../contracts/interfaces/IPostInteraction.sol";
import "./helpers/TestHelpers.sol";
import {TakerTraits} from "../contracts/libraries/TakerTraitsLib.sol";
import {IERC20} from "../dependencies/@openzeppelin-contracts-5.1.0/token/ERC20/IERC20.sol";
import {ERC20} from "../dependencies/@openzeppelin-contracts-5.1.0/token/ERC20/ERC20.sol";

// Mock contracts for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockWETH is MockERC20 {
    constructor() MockERC20("Wrapped Ether", "WETH") {}
}

// Simplified mock factory that just logs postInteraction calls
contract MockCrossChainEscrowFactory is IPostInteraction {
    event PostInteractionCalled(
        address indexed taker,
        uint256 makingAmount,
        uint256 takingAmount,
        bytes32 orderHash
    );

    bool public postInteractionCalled;
    address public lastTaker;
    uint256 public lastMakingAmount;
    uint256 public lastTakingAmount;
    bytes32 public lastOrderHash;

    function postInteraction(
        IOrderMixin.Order calldata,
        bytes calldata,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256,
        bytes calldata
    ) external override {
        postInteractionCalled = true;
        lastTaker = taker;
        lastMakingAmount = makingAmount;
        lastTakingAmount = takingAmount;
        lastOrderHash = orderHash;

        emit PostInteractionCalled(taker, makingAmount, takingAmount, orderHash);
    }
}

contract IntegrationTest is Test {
    using TestHelpers for *;

    SimpleLimitOrderProtocol public protocol;
    MockCrossChainEscrowFactory public factory;
    MockERC20 public srcToken;
    MockERC20 public dstToken;
    MockWETH public weth;

    address public alice;
    address public bob; // Resolver
    uint256 public alicePrivateKey = 0xA11CE;

    function setUp() public {
        // Set up accounts
        alice = vm.addr(alicePrivateKey);
        bob = address(0xB0B);
        
        // Deploy mock WETH
        weth = new MockWETH();

        // Deploy protocol
        protocol = new SimpleLimitOrderProtocol(IWETH(address(weth)));

        // Deploy mock factory
        factory = new MockCrossChainEscrowFactory();

        // Deploy tokens
        srcToken = new MockERC20("Source Token", "SRC");
        dstToken = new MockERC20("Destination Token", "DST");

        // Fund accounts
        srcToken.mint(alice, 10000 * 10**18);
        dstToken.mint(bob, 10000 * 10**18);

        // Approve protocol
        vm.prank(alice);
        srcToken.approve(address(protocol), type(uint256).max);
        
        vm.prank(bob);
        dstToken.approve(address(protocol), type(uint256).max);
    }

    function testFactoryPostInteractionTriggered() public {
        // This test demonstrates that filling an order with factory extension
        // triggers the postInteraction callback on the factory

        uint256 makingAmount = 1000 * 10**18;
        uint256 takingAmount = 500 * 10**18;

        // Create order with POST_INTERACTION flag using helper
        uint256 traits = TestHelpers.buildMakerTraits(
            false, // noPartialFills
            false, // hasExtension 
            true,  // postInteraction
            0,     // expiry
            address(0) // allowedSender
        );

        (IOrderMixin.Order memory order, bytes32 r, bytes32 vs) = TestHelpers.createAndSignOrder(
            alice,
            address(srcToken),
            address(dstToken),
            makingAmount,
            takingAmount,
            traits,
            protocol,
            alicePrivateKey,
            vm
        );

        // Initial state check
        assertFalse(factory.postInteractionCalled(), "Factory should not be called yet");

        // Fill order as Bob (resolver) with extension data
        bytes memory extensionData = abi.encode(address(factory));
        vm.prank(bob);
        protocol.fillOrder(order, r, vs, makingAmount, TakerTraits.wrap(0), extensionData);

        // Verify postInteraction was called
        assertTrue(factory.postInteractionCalled(), "Factory postInteraction should be called");
        assertEq(factory.lastTaker(), bob, "Taker should be Bob");
        assertEq(factory.lastMakingAmount(), makingAmount, "Making amount should match");
        assertEq(factory.lastTakingAmount(), takingAmount, "Taking amount should match");

        // Verify token transfers
        assertEq(srcToken.balanceOf(alice), 9000 * 10**18, "Alice should have sent tokens");
        assertEq(srcToken.balanceOf(bob), 1000 * 10**18, "Bob should have received tokens");
        assertEq(dstToken.balanceOf(bob), 9500 * 10**18, "Bob should have sent tokens");
        assertEq(dstToken.balanceOf(alice), 500 * 10**18, "Alice should have received tokens");
    }

    function testOrderWithoutPostInteraction() public {
        // Test that orders without POST_INTERACTION flag don't trigger factory

        uint256 makingAmount = 1000 * 10**18;
        uint256 takingAmount = 500 * 10**18;

        // Create order WITHOUT POST_INTERACTION flag using helper
        IOrderMixin.Order memory order = TestHelpers.createBasicOrder(
            alice,
            address(srcToken),
            address(dstToken),
            makingAmount,
            takingAmount
        );

        (bytes32 r, bytes32 vs) = TestHelpers.signOrder(order, protocol, alicePrivateKey, vm);

        // Build simple taker traits without extension
        TakerTraits takerTraits = TestHelpers.buildTakerTraits(
            takingAmount,
            false, // no extension
            address(0)
        );

        // Fill order without extension
        vm.prank(bob);
        protocol.fillOrder(order, r, vs, makingAmount, takerTraits);

        // Verify postInteraction was NOT called
        assertFalse(factory.postInteractionCalled(), "Factory should not be called for regular orders");

        // But tokens should still be transferred
        assertEq(srcToken.balanceOf(alice), 9000 * 10**18, "Alice should have sent tokens");
        assertEq(srcToken.balanceOf(bob), 1000 * 10**18, "Bob should have received tokens");
    }

    function testCrossChainOrderWithFactoryExtension() public {
        // Demonstrates a complete cross-chain order setup with factory extension data

        uint256 makingAmount = 2000 * 10**18;
        uint256 takingAmount = 1000 * 10**18;

        // Note: Extension data would be used in production but not needed for this test
        // since we're just verifying the postInteraction callback is triggered

        // Create order with both HAS_EXTENSION and POST_INTERACTION flags
        uint256 traits = TestHelpers.buildMakerTraits(
            false, // noPartialFills
            true,  // hasExtension
            true,  // postInteraction
            0,     // expiry
            address(0) // allowedSender
        );

        (IOrderMixin.Order memory order, bytes32 r, bytes32 vs) = TestHelpers.createAndSignOrder(
            alice,
            address(srcToken),
            address(dstToken),
            makingAmount,
            takingAmount,
            traits,
            protocol,
            alicePrivateKey,
            vm
        );

        // Build taker traits with extension
        TakerTraits takerTraits = TestHelpers.buildTakerTraits(
            takingAmount,
            true,
            address(factory)
        );

        // Fill order with factory interaction
        vm.prank(bob);
        protocol.fillOrder(order, r, vs, makingAmount, takerTraits);

        // Verify factory was called
        assertTrue(factory.postInteractionCalled(), "Factory should be called");
        assertEq(factory.lastMakingAmount(), makingAmount, "Making amount should match");
        assertEq(factory.lastTakingAmount(), takingAmount, "Taking amount should match");
    }
}