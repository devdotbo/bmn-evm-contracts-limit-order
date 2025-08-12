// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2, stdError} from "../dependencies/forge-std-1.10.0/src/Test.sol";
import {SimpleLimitOrderProtocol} from "../contracts/SimpleLimitOrderProtocol.sol";
import {IOrderMixin} from "../contracts/interfaces/IOrderMixin.sol";
import {IWETH} from "@1inch/solidity-utils/interfaces/IWETH.sol";
import {ERC20} from "../dependencies/@openzeppelin-contracts-5.1.0/token/ERC20/ERC20.sol";
import {Address, AddressLib} from "@1inch/solidity-utils/libraries/AddressLib.sol";
import {MakerTraits, MakerTraitsLib} from "../contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits} from "../contracts/libraries/TakerTraitsLib.sol";

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

contract PendingOrderReproTest is Test {
    using AddressLib for Address;

    SimpleLimitOrderProtocol public protocol;
    MockERC20 public token;
    MockWETH public weth;

    address public maker;
    address public taker;

    function setUp() public {
        maker = makeAddr("maker");
        taker = makeAddr("taker");
        token = new MockERC20("Token", "TKN");
        weth = new MockWETH();
        protocol = new SimpleLimitOrderProtocol(IWETH(address(weth)));

        token.mint(maker, 1_000 ether);
        token.mint(taker, 1_000 ether);

        vm.prank(maker);
        token.approve(address(protocol), type(uint256).max);

        vm.prank(taker);
        token.approve(address(protocol), type(uint256).max);
    }

    function test_Repro_PendingOrder_Overflow() public {
        // Values extracted from pending-orders JSON (normalized where needed)
        uint256 making = 0.01 ether; // 10000000000000000
        uint256 taking = 0.01 ether;
        // makerTraits from JSON
        uint256 makerTraitsVal = 4523128485832663883733241601901871400518358776001584532791311875309106626560;

        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 10789305505226621475235682392890947462797987815039319882236330451,
            maker: Address.wrap(uint256(uint160(maker))),
            receiver: Address.wrap(uint256(uint160(maker))),
            makerAsset: Address.wrap(uint256(uint160(address(token)))),
            takerAsset: Address.wrap(uint256(uint160(address(token)))),
            makingAmount: making,
            takingAmount: taking,
            makerTraits: MakerTraits.wrap(makerTraitsVal)
        });

        // Extension: use exact length and offsets from JSON (first 32 bytes offsets + 468 bytes data)
        bytes memory extension = hex"000001d400000000000000000000000000000000000000000000000000000000";
        extension = bytes.concat(extension, new bytes(468)); // stub data of same length

        // Signature dummy (not validated in this test since we expect early revert)
        bytes32 r = bytes32(uint256(1));
        bytes32 vs = bytes32(uint256(1) << 255);

        // takerTraits: maker-amount | argsExtensionLength(500) | threshold(taking)
        uint256 traitsVal = (uint256(1) << 255) | (uint256(500) << 224) | taking;
        TakerTraits takerTraits = TakerTraits.wrap(traitsVal);

        vm.prank(taker);
        vm.expectRevert(stdError.arithmeticError);
        protocol.fillOrderArgs(order, r, vs, making, takerTraits, extension);
    }
}


