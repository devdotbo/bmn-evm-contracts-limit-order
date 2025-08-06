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

contract DeployTestnet is Script {
    // CREATE3 Factory - should be same on testnets
    ICREATE3Factory constant CREATE3_FACTORY = 
        ICREATE3Factory(0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d);
    
    // Different salt for testnet to avoid conflicts
    bytes32 constant SALT = keccak256("BMN_LIMIT_ORDER_TESTNET_V1");
    
    // WETH on Optimism Sepolia and Base Sepolia
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("========================================");
        console.log("TESTNET Deployment");
        console.log("========================================");
        console.log("Deployer:", deployer);
        
        // Check chain
        uint256 chainId = block.chainid;
        require(
            chainId == 11155420 || // Optimism Sepolia
            chainId == 84532,       // Base Sepolia
            "Not on a supported testnet"
        );
        
        string memory chainName = chainId == 11155420 ? "Optimism Sepolia" : "Base Sepolia";
        console.log("Network:", chainName);
        
        // Get predicted address
        address payable predicted = payable(CREATE3_FACTORY.getDeployed(deployer, SALT));
        console.log("Predicted address:", predicted);
        
        // Check if already deployed
        if (predicted.code.length > 0) {
            console.log("Already deployed at:", predicted);
            
            // Test the deployed contract
            SimpleLimitOrderProtocol protocol = SimpleLimitOrderProtocol(predicted);
            console.log("Domain Separator:", vm.toString(protocol.DOMAIN_SEPARATOR()));
            return;
        }
        
        vm.startBroadcast(deployerKey);
        
        // Deploy
        bytes memory bytecode = abi.encodePacked(
            type(SimpleLimitOrderProtocol).creationCode,
            abi.encode(WETH)
        );
        
        address deployed = CREATE3_FACTORY.deploy(SALT, bytecode);
        
        console.log("[SUCCESS] DEPLOYED:", deployed);
        
        vm.stopBroadcast();
    }
}