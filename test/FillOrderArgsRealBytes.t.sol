// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "../dependencies/forge-std-1.10.0/src/Test.sol";
import {SimpleLimitOrderProtocol} from "../contracts/SimpleLimitOrderProtocol.sol";
import {IOrderMixin} from "../contracts/interfaces/IOrderMixin.sol";
import {IPostInteraction} from "../contracts/interfaces/IPostInteraction.sol";
import {IWETH} from "@1inch/solidity-utils/interfaces/IWETH.sol";
import {ERC20} from "../dependencies/@openzeppelin-contracts-5.1.0/token/ERC20/ERC20.sol";
import {IERC20} from "../dependencies/@openzeppelin-contracts-5.1.0/token/ERC20/IERC20.sol";
import {Address, AddressLib} from "@1inch/solidity-utils/libraries/AddressLib.sol";
import {MakerTraits, MakerTraitsLib} from "../contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits, TakerTraitsLib} from "../contracts/libraries/TakerTraitsLib.sol";
import {ExtensionLib} from "../contracts/libraries/ExtensionLib.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function decimals() public pure override returns (uint8) { return 18; }
}

contract MockWETH is IWETH, ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}
    function deposit() external payable override { _mint(msg.sender, msg.value); }
    function withdraw(uint256 amount) external override { _burn(msg.sender, amount); payable(msg.sender).transfer(amount); }
    receive() external payable { this.deposit{value: msg.value}(); }
}

contract MockPostInteractionReceiver is IPostInteraction {
    bool public called;
    address public lastTaker;
    uint256 public lastMakingAmount;
    uint256 public lastTakingAmount;
    function postInteraction(
        IOrderMixin.Order calldata,
        bytes calldata,
        bytes32,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256,
        bytes calldata
    ) external override {
        called = true;
        lastTaker = taker;
        lastMakingAmount = makingAmount;
        lastTakingAmount = takingAmount;
    }
}

contract FillOrderArgsRealBytesTest is Test {
    using AddressLib for Address;
    using MakerTraitsLib for MakerTraits;
    using TakerTraitsLib for TakerTraits;
    using ExtensionLib for bytes;

    uint256 constant MAKER_PK = 0x1111;
    uint256 constant RESOLVER_PK = 0x2222;

    SimpleLimitOrderProtocol public protocol;
    MockERC20 public tokenA; // maker sends A
    MockERC20 public tokenB; // taker sends B
    MockWETH public weth;
    MockPostInteractionReceiver public factory;

    address public maker;
    address public resolver;

    function setUp() public {
        maker = vm.addr(MAKER_PK);
        resolver = vm.addr(RESOLVER_PK);

        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        weth = new MockWETH();
        protocol = new SimpleLimitOrderProtocol(IWETH(address(weth)));
        factory = new MockPostInteractionReceiver();

        tokenA.mint(maker, 1_000 ether);
        tokenB.mint(resolver, 1_000 ether);

        vm.prank(maker);
        tokenA.approve(address(protocol), type(uint256).max);

        vm.prank(resolver);
        tokenB.approve(address(protocol), type(uint256).max);
    }

    function buildExtension(bytes memory postInteractionData) internal pure returns (bytes memory) {
        // end7 at bits [224..255], begin7 left as 0
        uint32 end7 = uint32(postInteractionData.length);
        uint256 offsets = uint256(end7) << 224;
        return bytes.concat(bytes32(offsets), postInteractionData);
    }

    function signOrder(IOrderMixin.Order memory order, uint256 pk) internal view returns (bytes32 r, bytes32 vs) {
        bytes32 orderHash = protocol.hashOrder(order);
        (uint8 v, bytes32 rr, bytes32 s) = vm.sign(pk, orderHash);
        r = rr;
        vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
    }

    function testFillOrderArgs_SucceedsWithRealExtensionBytes() public {
        uint256 making = 100 ether;
        uint256 taking = 95 ether;

        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(maker))),
            receiver: Address.wrap(uint256(uint160(maker))),
            makerAsset: Address.wrap(uint256(uint160(address(tokenA)))),
            takerAsset: Address.wrap(uint256(uint160(address(tokenB)))),
            makingAmount: making,
            takingAmount: taking,
            makerTraits: MakerTraits.wrap((1 << 249) | (1 << 251))
        });

        // Build postInteraction: 20-byte target (factory) + payload
        bytes memory payload = abi.encode(
            address(tokenA),
            address(tokenB),
            uint256(123456789),
            bytes32(uint256(0xDEADBEEF))
        );
        bytes memory postInteractionData = bytes.concat(bytes20(address(factory)), payload);
        bytes memory extension = buildExtension(postInteractionData);

        // Set salt lower160 to lower160(keccak256(extension)) per OrderLib.isValidExtension
        uint256 lower160 = uint256(keccak256(extension)) & type(uint160).max;
        uint256 upper96 = uint256(uint96(block.timestamp));
        order.salt = (upper96 << 160) | lower160;

        (bytes32 r, bytes32 vs) = signOrder(order, MAKER_PK);

        // takerTraits: maker-amount flag | argsExtensionLength | threshold=taking
        uint256 argsExtLen = extension.length;
        uint256 traitsVal = (uint256(1) << 255) | (argsExtLen << 224) | taking;
        TakerTraits takerTraits = TakerTraits.wrap(traitsVal);

        vm.prank(resolver);
        (uint256 gotMaking, uint256 gotTaking, ) = protocol.fillOrderArgs(
            order,
            r,
            vs,
            making,
            takerTraits,
            extension
        );

        assertEq(gotMaking, making, "makingAmount mismatch");
        assertEq(gotTaking, taking, "takingAmount mismatch");
        assertTrue(factory.called(), "postInteraction not called");
        assertEq(factory.lastTaker(), resolver, "taker mismatch");
    }
}


