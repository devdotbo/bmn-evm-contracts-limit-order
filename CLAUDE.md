# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build and Compilation
```bash
# Build the project with Foundry
forge build

# Install dependencies with Soldeer
forge soldeer install

# Update Soldeer dependencies and regenerate lock file
forge soldeer update
```

### Testing
```bash
# Run all tests
forge test

# Run tests with verbosity for debugging
forge test -vvv

# Run specific test
forge test --match-test testOrderFilling
```

### Deployment

#### Local Testing (Anvil)
```bash
# Start local Anvil instance
anvil

# Deploy to local network
source ../.env && \
forge script script/DeployLocal.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast
```

#### Mainnet Deployment
```bash
# Deploy to Optimism
source ../.env && \
forge script script/DeployMainnet.s.sol \
    --rpc-url $OPTIMISM_RPC \
    --broadcast \
    --verify

# Deploy to Base
source ../.env && \
forge script script/DeployMainnet.s.sol \
    --rpc-url $BASE_RPC \
    --broadcast \
    --verify
```

## Architecture Overview

This is a simplified implementation of the 1inch Limit Order Protocol designed to work with Bridge-Me-Not CrossChainEscrowFactory for atomic cross-chain swaps.

### Core Components

1. **SimpleLimitOrderProtocol** (`contracts/SimpleLimitOrderProtocol.sol`)
   - Main protocol contract stripped of whitelisting/staking features
   - Inherits from OrderMixin and EIP712 for order signing
   - Integrates with CrossChainEscrowFactory via postInteraction callbacks

2. **Order Processing Flow**
   - User creates limit order with factory extension data
   - Resolver fills order through SimpleLimitOrderProtocol
   - Protocol triggers postInteraction on CrossChainEscrowFactory
   - Factory creates source escrow with atomic swap parameters
   - Resolver creates destination escrow to complete swap

3. **Key Interfaces**
   - `IOrderMixin`: Core order filling interface
   - `IPostInteraction`: Factory callback interface for escrow creation
   - `ICreate3Deployer`: Deterministic deployment across chains

### Integration with Bridge-Me-Not Ecosystem

- **CrossChainEscrowFactory** (deployed on mainnet)
  - Optimism: `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c`
  - Base: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1`
  
- **CREATE3 Factory** (all chains): `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d`

### Order Extension Structure

Orders must include factory extension data to trigger cross-chain escrow creation:

```javascript
{
    factory: FACTORY_ADDRESS,
    destinationChainId: DEST_CHAIN_ID,
    destinationToken: TOKEN_ON_DEST_CHAIN,
    destinationReceiver: aliceAddress,
    timelocks: timelockConfig,
    hashlock: secretHash
}
```

## Dependencies

- **Foundry/Forge**: Development framework
- **Soldeer**: Dependency management for external libraries
- **forge-std v1.10.0**: Foundry standard library (installed via Soldeer)
- **OpenZeppelin v5.1.0**: Standard contract libraries (installed via Soldeer)
- **1inch Solidity Utils**: Core order utilities (referenced locally from ../solidity-utils)

## Related Repositories

- `../bmn-evm-contracts/`: Main protocol with CrossChainEscrowFactory
- `../limit-order-protocol/`: Original 1inch protocol reference
- `../bmn-evm-resolver/`: Resolver implementation
- `../bmn-evm-token/`: BMN token contracts

## Environment Variables

Required environment variables (sourced from `../.env`):
- `DEPLOYER_PRIVATE_KEY`: Deployment account private key
- `OPTIMISM_RPC`: Optimism RPC endpoint
- `BASE_RPC`: Base RPC endpoint

## Contract Configuration

- Solidity version: 0.8.23
- EVM version: Paris
- Optimizer: Enabled with 1,000,000 runs
- Dependency management: Soldeer (dependencies stored in `dependencies/` directory)
- Remappings configured in `foundry.toml`