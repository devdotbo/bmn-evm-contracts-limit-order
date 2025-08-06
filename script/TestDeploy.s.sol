// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimpleLimitOrderProtocol.sol";

contract TestDeploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Try to deploy directly on local fork
        vm.startBroadcast(deployerKey);
        
        address weth = 0x4200000000000000000000000000000000000006;
        SimpleLimitOrderProtocol protocol = new SimpleLimitOrderProtocol(IWETH(weth));
        
        console.log("Deployed SimpleLimitOrderProtocol at:", address(protocol));
        console.log("Domain Separator:", vm.toString(protocol.DOMAIN_SEPARATOR()));
        
        vm.stopBroadcast();
    }
}