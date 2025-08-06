// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../../contracts/interfaces/IOrderMixin.sol";
import "../../contracts/SimpleLimitOrderProtocol.sol";
import "../../contracts/libraries/MakerTraitsLib.sol";
import {Address, AddressLib} from "@1inch/solidity-utils/libraries/AddressLib.sol";
import {MakerTraits} from "../../contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits} from "../../contracts/libraries/TakerTraitsLib.sol";

library TestHelpers {
    // Bit flags for MakerTraits
    uint256 constant NO_PARTIAL_FILLS_FLAG = 1 << 255;
    uint256 constant ALLOW_MULTIPLE_FILLS_FLAG = 1 << 254;
    uint256 constant PRE_INTERACTION_CALL_FLAG = 1 << 252;
    uint256 constant POST_INTERACTION_CALL_FLAG = 1 << 251;
    uint256 constant NEED_CHECK_EPOCH_MANAGER_FLAG = 1 << 250;
    uint256 constant HAS_EXTENSION_FLAG = 1 << 249;
    uint256 constant USE_PERMIT2_FLAG = 1 << 248;
    uint256 constant UNWRAP_WETH_FLAG = 1 << 247;

    // Offsets for MakerTraits
    uint256 constant EXPIRATION_OFFSET = 80;
    uint256 constant NONCE_OR_EPOCH_OFFSET = 120;
    uint256 constant SERIES_OFFSET = 160;

    /// @notice Convert address to Address type used by protocol
    function toAddress(address addr) internal pure returns (Address) {
        return Address.wrap(uint256(uint160(addr)));
    }

    /// @notice Create a basic order with minimal parameters
    function createBasicOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    ) internal view returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, maker))),
            maker: toAddress(maker),
            receiver: toAddress(address(0)), // defaults to taker
            makerAsset: toAddress(makerAsset),
            takerAsset: toAddress(takerAsset),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: MakerTraits.wrap(0)
        });
    }

    /// @notice Create an order with custom traits
    function createOrderWithTraits(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 traits
    ) internal view returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: uint256(keccak256(abi.encodePacked(block.timestamp, maker, traits))),
            maker: toAddress(maker),
            receiver: toAddress(address(0)),
            makerAsset: toAddress(makerAsset),
            takerAsset: toAddress(takerAsset),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: MakerTraits.wrap(traits)
        });
    }

    /// @notice Sign an order using vm.sign
    function signOrder(
        IOrderMixin.Order memory order,
        SimpleLimitOrderProtocol protocol,
        uint256 privateKey,
        Vm vm
    ) internal view returns (bytes32 r, bytes32 vs) {
        // The hashOrder already returns the typed data hash with EIP-712
        // So we can sign it directly
        bytes32 typedDataHash = protocol.hashOrder(order);
        (uint8 v, bytes32 r_, bytes32 s) = vm.sign(privateKey, typedDataHash);
        r = r_;
        vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
    }

    /// @notice Build MakerTraits with common flags
    function buildMakerTraits(
        bool noPartialFills,
        bool hasExtension,
        bool postInteraction,
        uint256 expiry,
        address allowedSender
    ) internal pure returns (uint256) {
        uint256 traits = 0;
        
        if (noPartialFills) traits |= NO_PARTIAL_FILLS_FLAG;
        if (hasExtension) traits |= HAS_EXTENSION_FLAG;
        if (postInteraction) traits |= POST_INTERACTION_CALL_FLAG;
        
        if (expiry > 0) {
            traits |= (expiry << EXPIRATION_OFFSET);
        }
        
        if (allowedSender != address(0)) {
            traits |= uint256(uint160(allowedSender)) & ((1 << 80) - 1);
        }
        
        return traits;
    }

    /// @notice Build TakerTraits with threshold amount
    function buildTakerTraits(
        uint256 threshold,
        bool hasExtension,
        address extensionTarget
    ) internal pure returns (TakerTraits) {
        uint256 traits = threshold << 128;
        
        if (hasExtension) {
            traits |= (1 << 3); // Extension flag
            if (extensionTarget != address(0)) {
                traits |= uint256(uint160(extensionTarget)) << 4;
            }
        }
        
        return TakerTraits.wrap(traits);
    }

    /// @notice Create factory extension data for cross-chain swaps
    function createFactoryExtension(
        address factory,
        uint256 destinationChainId,
        address destinationToken,
        address destinationReceiver,
        uint256[2] memory timelocks,
        bytes32 hashlock
    ) internal pure returns (bytes memory) {
        return abi.encode(
            factory,
            destinationChainId,
            destinationToken,
            destinationReceiver,
            timelocks,
            hashlock
        );
    }

    /// @notice Create a simple order and sign it in one step
    function createAndSignOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 traits,
        SimpleLimitOrderProtocol protocol,
        uint256 privateKey,
        Vm vm
    ) internal view returns (IOrderMixin.Order memory order, bytes32 r, bytes32 vs) {
        order = createOrderWithTraits(
            maker,
            makerAsset,
            takerAsset,
            makingAmount,
            takingAmount,
            traits
        );
        (r, vs) = signOrder(order, protocol, privateKey, vm);
    }
}