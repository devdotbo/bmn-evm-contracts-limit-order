// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "../dependencies/forge-std-1.10.0/src/Test.sol";
import {OffsetsInspector} from "../contracts/helpers/OffsetsInspector.sol";

contract OffsetsInspectorTest is Test {
    OffsetsInspector inspector;

    function setUp() public {
        inspector = new OffsetsInspector();
    }

    function buildExtension(bytes memory postInteractionData) internal pure returns (bytes memory) {
        // Set end7 in the highest 4 bytes (bits [224..255]). begin7 remains 0.
        uint32 end7 = uint32(postInteractionData.length);
        uint256 offsets = uint256(end7) << 224;
        return bytes.concat(bytes32(offsets), postInteractionData);
    }

    function testInspectOffsetsAndPostInteraction() public {
        address factory = address(0xB436dBBee1615dd80ff036Af81D8478c1FF1Eb68);

        // Dummy payload after the 20-byte target
        bytes memory payload = abi.encode(
            address(0x77CC1A51dC5855bcF0d9f1c1FceaeE7fb855a535),
            address(0x36938b7899A17362520AA741C0E0dA0c8EfE5e3b),
            uint256(123),
            bytes32(uint256(456)),
            address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8)
        );

        bytes memory postInteractionData = bytes.concat(bytes20(factory), payload);
        bytes memory extension = buildExtension(postInteractionData);

        (uint32[8] memory ends, uint32 begin7, uint32 end7, address target, bytes memory postData) =
            inspector.inspect(extension);

        assertEq(begin7, 0, "begin7 must be 0 when fields 0..6 are empty");
        assertEq(end7, uint32(postInteractionData.length), "end7 must equal postInteractionData length");
        for (uint256 i = 0; i < 7; i++) {
            assertEq(ends[i], 0, "fields 0..6 should be empty");
        }
        assertEq(ends[7], end7, "ends[7] mismatch");
        assertEq(target, factory, "target should equal factory");
        assertEq(postData.length, postInteractionData.length - 20, "postData length mismatch");
    }
}


