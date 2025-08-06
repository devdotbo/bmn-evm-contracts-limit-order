// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimpleLimitOrderProtocol.sol";

interface ICREATE3Factory {
    function getDeployed(address deployer, bytes32 salt) 
        external view returns (address);
}

contract CheckDeployment is Script {
    ICREATE3Factory constant CREATE3_FACTORY = 
        ICREATE3Factory(0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d);
    
    bytes32 constant MAINNET_SALT = keccak256("BMN_LIMIT_ORDER_V1");
    bytes32 constant TESTNET_SALT = keccak256("BMN_LIMIT_ORDER_TESTNET_V1");
    
    function run() external view {
        address deployer;
        
        // Try to get deployer from private key first
        try vm.envUint("DEPLOYER_PRIVATE_KEY") returns (uint256 key) {
            deployer = vm.addr(key);
        } catch {
            // Fall back to address if private key not available
            try vm.envAddress("DEPLOYER_ADDRESS") returns (address addr) {
                deployer = addr;
            } catch {
                console.log("ERROR: Set DEPLOYER_PRIVATE_KEY or DEPLOYER_ADDRESS in .env");
                return;
            }
        }
        
        console.log("========================================");
        console.log("Deployment Address Checker");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("");
        
        // Check mainnet predicted address
        address payable mainnetPredicted = payable(CREATE3_FACTORY.getDeployed(deployer, MAINNET_SALT));
        console.log("MAINNET Predicted Address:");
        console.log("  Same address on Optimism & Base:", mainnetPredicted);
        
        // Check if deployed
        if (mainnetPredicted.code.length > 0) {
            console.log("  [DEPLOYED] Already deployed!");
            SimpleLimitOrderProtocol protocol = SimpleLimitOrderProtocol(mainnetPredicted);
            console.log("  Domain Separator:", vm.toString(protocol.DOMAIN_SEPARATOR()));
        } else {
            console.log("  [PENDING] Not yet deployed");
        }
        
        console.log("");
        
        // Check testnet predicted address
        address payable testnetPredicted = payable(CREATE3_FACTORY.getDeployed(deployer, TESTNET_SALT));
        console.log("TESTNET Predicted Address:");
        console.log("  Same on Optimism Sepolia & Base Sepolia:", testnetPredicted);
        
        if (testnetPredicted.code.length > 0) {
            console.log("  [DEPLOYED] Already deployed!");
            SimpleLimitOrderProtocol protocol = SimpleLimitOrderProtocol(testnetPredicted);
            console.log("  Domain Separator:", vm.toString(protocol.DOMAIN_SEPARATOR()));
        } else {
            console.log("  [PENDING] Not yet deployed");
        }
        
        console.log("");
        console.log("Factory Addresses:");
        console.log("  Optimism CrossChainEscrowFactory: 0xB916C3edbFe574fFCBa688A6B92F72106479bD6c");
        console.log("  Base CrossChainEscrowFactory: 0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1");
        console.log("");
        console.log("To deploy:");
        console.log("  Mainnet: forge script script/DeployMainnet.s.sol --rpc-url <RPC> --broadcast");
        console.log("  Testnet: forge script script/DeployTestnet.s.sol --rpc-url <RPC> --broadcast");
    }
}