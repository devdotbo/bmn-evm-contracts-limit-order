// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std-1.10.0/Script.sol";
import "../contracts/SimpleLimitOrderProtocol.sol";

contract DeployLocal is Script {
    function run() external {
        // Read from ../bmn-evm-contracts/.env if needed
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        // Use same WETH as main contracts
        address weth = 0x4200000000000000000000000000000000000006;
        
        vm.startBroadcast(deployerKey);
        
        SimpleLimitOrderProtocol protocol = new SimpleLimitOrderProtocol(
            IWETH(weth)
        );
        
        console.log("[DEPLOYED] SimpleLimitOrderProtocol:", address(protocol));
        
        // Save deployment info
        string memory json = "deployment";
        vm.serializeAddress(json, "limitOrderProtocol", address(protocol));
        vm.writeJson(json, "deployments/local.json");
        
        vm.stopBroadcast();
    }
}