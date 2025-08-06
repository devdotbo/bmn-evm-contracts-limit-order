// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {SimpleLimitOrderProtocol} from "../contracts/SimpleLimitOrderProtocol.sol";
import {IOrderMixin} from "../contracts/interfaces/IOrderMixin.sol";
import {IPostInteraction} from "../contracts/interfaces/IPostInteraction.sol";
import {MakerTraits, MakerTraitsLib} from "../contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits} from "../contracts/libraries/TakerTraitsLib.sol";
import "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped ETH", "WETH") {}
    
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }
    
    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockCrossChainEscrowFactory is IPostInteraction {
    event EscrowCreated(
        address indexed maker,
        bytes32 indexed orderHash,
        uint256 destinationChainId,
        address destinationToken,
        address destinationReceiver,
        uint256 amount
    );
    
    struct EscrowParams {
        uint256 destinationChainId;
        address destinationToken;
        address destinationReceiver;
        uint256 timelocks;
        bytes32 hashlock;
    }
    
    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external override {
        EscrowParams memory params = abi.decode(extension, (EscrowParams));
        
        emit EscrowCreated(
            AddressLib.get(order.maker),
            orderHash,
            params.destinationChainId,
            params.destinationToken,
            params.destinationReceiver,
            makingAmount
        );
    }
}

contract SimpleLimitOrderProtocolTest is Test {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    
    SimpleLimitOrderProtocol public protocol;
    MockWETH public weth;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockCrossChainEscrowFactory public factory;
    
    address public alice = address(0xa11ce);
    address public bob = address(0xb0b);
    address public resolver = address(0x12e501);
    
    uint256 public alicePrivateKey = 0x1234;
    uint256 public bobPrivateKey = 0x5678;
    
    function setUp() public {
        weth = new MockWETH();
        protocol = new SimpleLimitOrderProtocol(IWETH(address(weth)));
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        factory = new MockCrossChainEscrowFactory();
        
        tokenA.mint(alice, 1000 ether);
        tokenB.mint(bob, 1000 ether);
        tokenB.mint(resolver, 1000 ether);
        
        vm.prank(alice);
        tokenA.approve(address(protocol), type(uint256).max);
        
        vm.prank(bob);
        tokenB.approve(address(protocol), type(uint256).max);
        
        vm.prank(resolver);
        tokenB.approve(address(protocol), type(uint256).max);
    }
    
    function testSimpleOrderFilling() public {
        IOrderMixin.Order memory order = createBasicOrder(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether
        );
        
        bytes32 orderHash = protocol.hashOrder(order);
        
        (bytes32 r, bytes32 vs) = signOrder(orderHash, alicePrivateKey);
        
        uint256 aliceBalanceBefore = tokenB.balanceOf(alice);
        uint256 bobBalanceBefore = tokenA.balanceOf(bob);
        
        vm.prank(bob);
        (uint256 makingAmount, uint256 takingAmount, bytes32 filledHash) = protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
        
        assertEq(makingAmount, 100 ether);
        assertEq(takingAmount, 50 ether);
        assertEq(filledHash, orderHash);
        assertEq(tokenB.balanceOf(alice), aliceBalanceBefore + 50 ether);
        assertEq(tokenA.balanceOf(bob), bobBalanceBefore + 100 ether);
    }
    
    function testPartialOrderFilling() public {
        IOrderMixin.Order memory order = createBasicOrder(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether
        );
        
        order.makerTraits = MakerTraitsLib.setAllowPartialFills(order.makerTraits, true);
        
        bytes32 orderHash = protocol.hashOrder(order);
        (bytes32 r, bytes32 vs) = signOrder(orderHash, alicePrivateKey);
        
        vm.prank(bob);
        (uint256 makingAmount1, uint256 takingAmount1,) = protocol.fillOrder(
            order,
            r,
            vs,
            25 ether,
            TakerTraits.wrap(0)
        );
        
        assertEq(makingAmount1, 50 ether);
        assertEq(takingAmount1, 25 ether);
        
        vm.prank(bob);
        (uint256 makingAmount2, uint256 takingAmount2,) = protocol.fillOrder(
            order,
            r,
            vs,
            25 ether,
            TakerTraits.wrap(0)
        );
        
        assertEq(makingAmount2, 50 ether);
        assertEq(takingAmount2, 25 ether);
    }
    
    function testOrderWithFactoryExtension() public {
        bytes memory extensionData = encodeFactoryExtension(
            address(factory),
            10,
            address(tokenB),
            alice,
            block.timestamp + 1 hours,
            keccak256("secret")
        );
        
        IOrderMixin.Order memory order = createOrderWithExtension(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether,
            extensionData
        );
        
        bytes32 orderHash = protocol.hashOrder(order);
        (bytes32 r, bytes32 vs) = signOrder(orderHash, alicePrivateKey);
        
        vm.expectEmit(true, true, false, true);
        emit MockCrossChainEscrowFactory.EscrowCreated(
            alice,
            orderHash,
            10,
            address(tokenB),
            alice,
            100 ether
        );
        
        vm.prank(resolver);
        protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
    }
    
    function testOrderCancellation() public {
        IOrderMixin.Order memory order = createBasicOrder(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether
        );
        
        bytes32 orderHash = protocol.hashOrder(order);
        
        vm.prank(alice);
        protocol.cancelOrder(order.makerTraits, orderHash);
        
        (bytes32 r, bytes32 vs) = signOrder(orderHash, alicePrivateKey);
        
        vm.prank(bob);
        vm.expectRevert(IOrderMixin.InvalidatedOrder.selector);
        protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
    }
    
    function testInvalidSignatureReverts() public {
        IOrderMixin.Order memory order = createBasicOrder(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether
        );
        
        bytes32 orderHash = protocol.hashOrder(order);
        (bytes32 r, bytes32 vs) = signOrder(orderHash, bobPrivateKey);
        
        vm.prank(bob);
        vm.expectRevert(IOrderMixin.BadSignature.selector);
        protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
    }
    
    function testDomainSeparator() public view {
        bytes32 domainSeparator = protocol.DOMAIN_SEPARATOR();
        assertTrue(domainSeparator != bytes32(0));
    }
    
    function testOrderExpiry() public {
        IOrderMixin.Order memory order = createBasicOrder(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether
        );
        
        order.makerTraits = MakerTraitsLib.setExpiry(order.makerTraits, uint32(block.timestamp - 1));
        
        bytes32 orderHash = protocol.hashOrder(order);
        (bytes32 r, bytes32 vs) = signOrder(orderHash, alicePrivateKey);
        
        vm.prank(bob);
        vm.expectRevert(IOrderMixin.OrderExpired.selector);
        protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
    }
    
    function testPrivateOrder() public {
        IOrderMixin.Order memory order = createBasicOrder(
            alice,
            address(tokenA),
            address(tokenB),
            100 ether,
            50 ether
        );
        
        order.makerTraits = MakerTraitsLib.setAllowedSender(order.makerTraits, resolver);
        
        bytes32 orderHash = protocol.hashOrder(order);
        (bytes32 r, bytes32 vs) = signOrder(orderHash, alicePrivateKey);
        
        vm.prank(bob);
        vm.expectRevert(IOrderMixin.PrivateOrder.selector);
        protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
        
        vm.prank(resolver);
        (uint256 makingAmount, uint256 takingAmount,) = protocol.fillOrder(
            order,
            r,
            vs,
            50 ether,
            TakerTraits.wrap(0)
        );
        
        assertEq(makingAmount, 100 ether);
        assertEq(takingAmount, 50 ether);
    }
    
    function createBasicOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    ) internal pure returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(maker, block.timestamp))),
            maker: AddressLib.from(maker),
            receiver: AddressLib.from(maker),
            makerAsset: AddressLib.from(makerAsset),
            takerAsset: AddressLib.from(takerAsset),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: MakerTraits.wrap(0)
        });
    }
    
    function createOrderWithExtension(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        bytes memory extension
    ) internal pure returns (IOrderMixin.Order memory) {
        IOrderMixin.Order memory order = createBasicOrder(
            maker,
            makerAsset,
            takerAsset,
            makingAmount,
            takingAmount
        );
        
        order.makerTraits = MakerTraitsLib.setHasExtension(order.makerTraits, true);
        
        order.makerTraits = MakerTraitsLib.setMakerAssetSuffix(
            order.makerTraits,
            extension
        );
        
        return order;
    }
    
    function encodeFactoryExtension(
        address factoryAddress,
        uint256 destChainId,
        address destToken,
        address destReceiver,
        uint256 timelocks,
        bytes32 hashlock
    ) internal pure returns (bytes memory) {
        bytes memory factoryData = abi.encode(
            destChainId,
            destToken,
            destReceiver,
            timelocks,
            hashlock
        );
        
        return abi.encodePacked(
            bytes20(factoryAddress),
            factoryData
        );
    }
    
    function signOrder(bytes32 orderHash, uint256 privateKey) internal view returns (bytes32 r, bytes32 vs) {
        bytes32 domainSeparator = protocol.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, orderHash));
        
        (uint8 v, bytes32 r_, bytes32 s) = vm.sign(privateKey, digest);
        
        r = r_;
        vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
    }
}