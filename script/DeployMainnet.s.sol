// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimpleLimitOrderProtocol.sol";

interface ICREATE3Factory {
    function deploy(bytes32 salt, bytes memory creationCode) 
        external returns (address);
    
    function getDeployed(address deployer, bytes32 salt) 
        external view returns (address);
}

contract DeployMainnet is Script {
    ICREATE3Factory constant factory = 
        ICREATE3Factory(0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d);
    
    bytes32 constant SALT = keccak256("BMN_LIMIT_ORDER_V1");
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address weth = 0x4200000000000000000000000000000000000006;
        
        vm.startBroadcast(deployerKey);
        
        // Check predicted address
        address predicted = factory.getDeployed(msg.sender, SALT);
        console.log("Predicted address:", predicted);
        
        // Deploy with CREATE3 for same address on all chains
        bytes memory bytecode = abi.encodePacked(
            type(SimpleLimitOrderProtocol).creationCode,
            abi.encode(weth)
        );
        
        address deployed = factory.deploy(SALT, bytecode);
        console.log("[DEPLOYED] SimpleLimitOrderProtocol:", deployed);
        
        vm.stopBroadcast();
    }
}