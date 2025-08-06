# 1inch Limit Order Protocol Deployment Plan

## Critical Mission: Enable Atomic Swaps via 1inch Infrastructure

### Problem Statement
The CrossChainEscrowFactory deployed on mainnet cannot create atomic swaps directly. It's designed as a 1inch extension that requires a LimitOrderProtocol to trigger its `postInteraction` callback. Without this, the resolver cannot initiate cross-chain swaps.

### Solution
Deploy our own LimitOrderProtocol instance (without whitelisting/staking) that integrates with the existing CrossChainEscrowFactory.

## Project Structure

```
bridge-me-not/
├── bmn-evm-contracts/              # Main protocol contracts (CrossChainEscrowFactory)
├── bmn-evm-contracts-limit-order/  # THIS PROJECT - Custom 1inch deployment
├── limit-order-protocol/            # Unchanged 1inch source (latest main branch)
├── bmn-evm-resolver/               # Resolver implementation
└── bmn-evm-token/                  # BMN token contracts
```

### Key Addresses
- **Optimism Factory**: 0xB916C3edbFe574fFCBa688A6B92F72106479bD6c
- **Base Factory**: 0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1
- **CREATE3 Factory**: 0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d (all chains)

## Phase 1: Project Setup [IMMEDIATE ACTION]

### 1.1 Copy Core Files from 1inch
Source directory: `../limit-order-protocol/contracts/`

Files to copy:
```bash
# Core order logic
cp ../limit-order-protocol/contracts/OrderMixin.sol contracts/
cp ../limit-order-protocol/contracts/OrderLib.sol contracts/

# Required libraries
cp -r ../limit-order-protocol/contracts/libraries contracts/
cp -r ../limit-order-protocol/contracts/interfaces contracts/

# Helper contracts
cp -r ../limit-order-protocol/contracts/helpers contracts/
```

### 1.2 Install Dependencies
```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install 1inch/solidity-utils --no-commit
```

### 1.3 Create Simplified LimitOrderProtocol

Create `contracts/SimpleLimitOrderProtocol.sol`:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./OrderMixin.sol";

/**
 * @title Simple Limit Order Protocol for Bridge-Me-Not
 * @notice Stripped down version - no pausing, no whitelisting, no staking
 * @dev Designed to work with CrossChainEscrowFactory as an extension
 */
contract SimpleLimitOrderProtocol is 
    EIP712("Bridge-Me-Not Orders", "1"),
    OrderMixin
{
    constructor(IWETH _weth) OrderMixin(_weth) {}

    function DOMAIN_SEPARATOR() external view returns(bytes32) {
        return _domainSeparatorV4();
    }
}
```

## Phase 2: Integration Architecture

### How It Works

```
1. Alice creates a limit order with factory extension data
2. Resolver fills the order through LimitOrderProtocol
3. LimitOrderProtocol calls factory.postInteraction()
4. Factory creates source escrow with atomic swap parameters
5. Resolver creates destination escrow
6. Atomic swap completes
```

### Order Structure with Extension

```javascript
const order = {
    salt: uniqueSalt,
    makerAsset: TOKEN_ON_SOURCE_CHAIN,
    takerAsset: 0x0, // Resolver provides
    maker: aliceAddress,
    receiver: aliceAddress,
    allowedSender: resolverAddress,
    makingAmount: amount,
    takingAmount: expectedAmount,
    offsets: packOffsets({hasExtension: true}),
    interactions: encodeExtension({
        factory: FACTORY_ADDRESS,
        destinationChainId: DEST_CHAIN_ID,
        destinationToken: TOKEN_ON_DEST_CHAIN,
        destinationReceiver: aliceAddress,
        timelocks: timelockConfig,
        hashlock: secretHash
    })
};
```

## Phase 3: Deployment Scripts

### 3.1 Local Deployment
Create `script/DeployLocal.s.sol`:

```solidity
pragma solidity 0.8.23;

import "forge-std/Script.sol";
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
```

### 3.2 Mainnet Deployment with CREATE3
Create `script/DeployMainnet.s.sol`:

```solidity
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
```

### 3.3 Deployment Commands

```bash
# Local testing (Anvil)
source ../bmn-evm-contracts/.env && \
forge script script/DeployLocal.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast

# Optimism Mainnet
source ../bmn-evm-contracts/.env && \
forge script script/DeployMainnet.s.sol \
    --rpc-url $OPTIMISM_RPC \
    --broadcast \
    --verify

# Base Mainnet  
source ../bmn-evm-contracts/.env && \
forge script script/DeployMainnet.s.sol \
    --rpc-url $BASE_RPC \
    --broadcast \
    --verify
```

## Phase 4: Testing Integration

### 4.1 Create Test Script
Create `script/TestIntegration.s.sol`:

```solidity
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/SimpleLimitOrderProtocol.sol";
import "../../bmn-evm-contracts/contracts/CrossChainEscrowFactory.sol";

contract TestIntegration is Script {
    function run() external {
        // Load deployed addresses
        address protocol = vm.envAddress("LIMIT_ORDER_PROTOCOL");
        address factory = vm.envAddress("ESCROW_FACTORY");
        
        // Create test order with factory extension
        // Fill order to trigger factory
        // Verify escrow created
    }
}
```

### 4.2 Integration Test Flow

1. **Setup**
   - Deploy SimpleLimitOrderProtocol
   - Use existing CrossChainEscrowFactory from `../bmn-evm-contracts`
   - Fund test accounts

2. **Order Creation (Alice)**
   - Approve tokens to LimitOrderProtocol
   - Create order with factory extension data
   - Sign order with EIP-712

3. **Order Filling (Resolver)**
   - Call `fillOrder` on LimitOrderProtocol
   - This triggers `postInteraction` on factory
   - Factory creates source escrow

4. **Verification**
   - Check escrow deployed at expected address
   - Verify escrow parameters match order
   - Confirm tokens locked in escrow

## Phase 5: Resolver Updates

The resolver at `../bmn-evm-resolver` needs updates:

### 5.1 Replace Direct Factory Calls

**OLD (doesn't work):**
```typescript
await factory.postSourceEscrow(...) // Function doesn't exist!
```

**NEW (correct flow):**
```typescript
// Create order
const order = createOrderWithExtension(swapParams)
const signature = await alice.signOrder(order)

// Fill order (triggers factory)
await limitOrderProtocol.fillOrder(
    order,
    signature, 
    makingAmount,
    takingAmount,
    resolver.address
)
```

### 5.2 Order Monitoring

```typescript
// Listen for OrderFilled events
limitOrderProtocol.on("OrderFilled", (orderHash, maker) => {
    // Order filled, escrow should be created
    // Continue with destination escrow deployment
})
```

## Phase 6: Verification Checklist

### Pre-Mainnet Testing
- [ ] Deploy to local Anvil chains
- [ ] Create order with factory extension
- [ ] Fill order successfully
- [ ] Verify factory.postInteraction called
- [ ] Confirm source escrow created
- [ ] Complete full atomic swap

### Mainnet Deployment
- [ ] Deploy to Optimism (CREATE3)
- [ ] Deploy to Base (same address via CREATE3)
- [ ] Verify on Etherscan
- [ ] Update resolver configuration
- [ ] Test with small amounts
- [ ] Monitor first production swap

## Critical Notes

### Why This Approach Works
1. **Minimal Changes** - SimpleLimitOrderProtocol is just 1inch without extras
2. **Factory Unchanged** - CrossChainEscrowFactory already supports this flow
3. **Standard 1inch Flow** - Uses proven order/fill mechanics
4. **No Whitelisting** - Anyone can create/fill orders

### Common Pitfalls to Avoid
1. **Don't modify factory** - It's already correct
2. **Don't skip extension data** - Orders must include factory params
3. **Don't forget approvals** - Alice must approve LimitOrderProtocol
4. **Don't mix environments** - Keep mainnet/testnet separate

### Resources
- **1inch Source**: `../limit-order-protocol/`
- **Main Contracts**: `../bmn-evm-contracts/`  
- **Resolver Code**: `../bmn-evm-resolver/`
- **Token Contracts**: `../bmn-evm-token/`

## Quick Start for Agent

```bash
# 1. Setup project
cd bmn-evm-contracts-limit-order
forge build

# 2. Copy required files from 1inch
cp ../limit-order-protocol/contracts/OrderMixin.sol contracts/
cp ../limit-order-protocol/contracts/OrderLib.sol contracts/
cp -r ../limit-order-protocol/contracts/libraries contracts/
cp -r ../limit-order-protocol/contracts/interfaces contracts/

# 3. Create SimpleLimitOrderProtocol.sol (see above)

# 4. Deploy locally
forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast

# 5. Test integration
forge test -vvv

# 6. Deploy to mainnet when ready
```

## Success Metrics

1. **SimpleLimitOrderProtocol deployed** to Optimism & Base
2. **Orders can be created** with factory extension
3. **Filling orders triggers** factory.postInteraction()  
4. **Source escrows created** automatically
5. **Resolver completes** atomic swaps end-to-end
6. **Mainnet swaps** working Optimism ↔ Base

---

**URGENT**: The resolver is blocked until this is deployed. This is the missing piece that enables the entire atomic swap protocol to function on mainnet.