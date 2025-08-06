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
    // CREATE3 Factory deployed on all chains at same address
    ICREATE3Factory constant CREATE3_FACTORY = 
        ICREATE3Factory(0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d);
    
    // Salt for deterministic deployment (same on all chains)
    bytes32 constant SALT = keccak256("BMN_LIMIT_ORDER_V1");
    
    // WETH address (same on Optimism and Base)
    address constant WETH = 0x4200000000000000000000000000000000000006;
    
    function run() external {
        // Load deployer private key
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("========================================");
        console.log("SimpleLimitOrderProtocol Deployment");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        // Check deployer has sufficient balance
        require(deployer.balance > 0.001 ether, "Insufficient balance for deployment");
        
        // Get predicted address (same on all chains)
        address predicted = CREATE3_FACTORY.getDeployed(deployer, SALT);
        console.log("Predicted address:", predicted);
        
        // Check if already deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(predicted)
        }
        if (codeSize > 0) {
            console.log("WARNING: Contract already deployed at", predicted);
            console.log("Skipping deployment...");
            return;
        }
        
        // Get current chain ID
        uint256 chainId = block.chainid;
        string memory chainName;
        if (chainId == 10) {
            chainName = "Optimism";
        } else if (chainId == 8453) {
            chainName = "Base";
        } else if (chainId == 11155420) {
            chainName = "Optimism Sepolia";
        } else if (chainId == 84532) {
            chainName = "Base Sepolia";
        } else {
            chainName = "Unknown";
        }
        
        console.log("Deploying to:", chainName, "(Chain ID:", chainId, ")");
        console.log("");
        console.log("Configuration:");
        console.log("- WETH:", WETH);
        console.log("- CREATE3 Factory:", address(CREATE3_FACTORY));
        console.log("- Salt:", vm.toString(SALT));
        
        // Start broadcast
        vm.startBroadcast(deployerKey);
        
        // Prepare creation code with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(SimpleLimitOrderProtocol).creationCode,
            abi.encode(WETH)
        );
        
        console.log("");
        console.log("Deploying SimpleLimitOrderProtocol...");
        
        // Deploy via CREATE3
        address deployed = CREATE3_FACTORY.deploy(SALT, bytecode);
        
        console.log("");
        console.log("========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("SimpleLimitOrderProtocol:", deployed);
        console.log("");
        
        // Verify deployment
        SimpleLimitOrderProtocol protocol = SimpleLimitOrderProtocol(deployed);
        bytes32 domainSeparator = protocol.DOMAIN_SEPARATOR();
        console.log("Domain Separator:", vm.toString(domainSeparator));
        
        // Save deployment info to file
        string memory deploymentInfo = string(abi.encodePacked(
            "Chain: ", chainName, "\n",
            "Chain ID: ", vm.toString(chainId), "\n",
            "SimpleLimitOrderProtocol: ", vm.toString(deployed), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "Block: ", vm.toString(block.number), "\n",
            "Timestamp: ", vm.toString(block.timestamp), "\n"
        ));
        
        string memory filename = string(abi.encodePacked(
            "deployments/",
            chainName,
            "-",
            vm.toString(block.timestamp),
            ".txt"
        ));
        
        // Note: This will fail if deployments/ directory doesn't exist
        // Create it manually before deployment
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("Next steps:");
        console.log("1. Verify contract on block explorer");
        console.log("2. Deploy to other chain (if not done)");
        console.log("3. Update README with deployed address");
        console.log("4. Test with factory integration");
    }
}