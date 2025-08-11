// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../libraries/ExtensionLib.sol";

/// @title OffsetsInspector
/// @notice Utility contract to inspect 1inch-style extension bytes and verify offsets layout
contract OffsetsInspector {
    using ExtensionLib for bytes;

    /// Inspect a 1inch extension payload.
    /// - ends: end offsets for fields 0..7 (uint32 each)
    /// - begin7: begin offset of field 7 (postInteraction)
    /// - end7: end offset of field 7 (postInteraction)
    /// - target: address in first 20 bytes of postInteraction segment (if present)
    /// - postData: remainder bytes after the 20-byte target (or entire segment if < 20 bytes)
    function inspect(
        bytes calldata extension
    )
        external
        pure
        returns (
            uint32[8] memory ends,
            uint32 begin7,
            uint32 end7,
            address target,
            bytes memory postData
        )
    {
        if (extension.length >= 32) {
            uint256 off = uint256(bytes32(extension));
            unchecked {
                // Extract end values for fields 0..7 (each 32-bit)
                for (uint256 i = 0; i < 8; i++) {
                    ends[i] = uint32(off >> (i * 32));
                }
                // begin7 occupies bits [192..223], end7 is already in ends[7]
                begin7 = uint32(off >> 192);
                end7 = ends[7];
            }
        }

        bytes calldata seg = extension.postInteractionTargetAndData();
        if (seg.length > 19) {
            target = address(bytes20(seg));
            postData = abi.encodePacked(seg[20:]);
        } else {
            target = address(0);
            postData = abi.encodePacked(seg);
        }
    }
}


