# Bridge-Me-Not Limit Order Protocol

## Overview

This repository contains a simplified implementation of the 1inch Limit Order Protocol, specifically designed to work with the Bridge-Me-Not CrossChainEscrowFactory for enabling atomic cross-chain swaps.

## Problem & Solution

The CrossChainEscrowFactory deployed on mainnet cannot create atomic swaps directly. It's designed as a 1inch extension that requires a LimitOrderProtocol to trigger its `postInteraction` callback. This project provides that missing piece - a SimpleLimitOrderProtocol that integrates seamlessly with the existing factory infrastructure.

## Key Features

- **Simplified Protocol**: Stripped down version of 1inch Limit Order Protocol without whitelisting or staking requirements
- **Cross-Chain Ready**: Designed to work with CrossChainEscrowFactory for atomic swaps
- **CREATE3 Deployment**: Ensures same address across all chains for consistency
- **Soldeer Dependency Management**: Modern dependency management without git submodule issues

## Architecture

```
User (Alice) → Creates Order with Factory Extension
     ↓
Resolver → Fills Order through SimpleLimitOrderProtocol
     ↓
Protocol → Triggers postInteraction on Factory
     ↓
Factory → Creates Source Escrow with Atomic Swap Parameters
     ↓
Resolver → Creates Destination Escrow
     ↓
Atomic Swap Complete ✓
```

## Deployed Addresses

### Mainnet Contracts
- **Optimism Factory**: `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c`
- **Base Factory**: `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1`
- **CREATE3 Factory**: `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` (all chains)

### SimpleLimitOrderProtocol
- **Optimism**: (To be deployed)
- **Base**: (To be deployed)

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd bmn-evm-contracts-limit-order

# Install dependencies with Soldeer
forge soldeer install

# Build the project
forge build
```

## Deployment

### Local Testing (Anvil)

```bash
# Start local Anvil instance
anvil

# Deploy to local network
source ../.env && \
forge script script/DeployLocal.s.sol \
    --rpc-url http://localhost:8545 \
    --broadcast
```

### Mainnet Deployment

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

## Usage Example

### Creating an Order with Factory Extension

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

### Filling an Order (Resolver)

```javascript
await limitOrderProtocol.fillOrder(
    order,
    signature,
    makingAmount,
    takingAmount,
    resolver.address
);
```

## Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test testOrderFilling
```

## Project Structure

```
bmn-evm-contracts-limit-order/
├── contracts/
│   ├── SimpleLimitOrderProtocol.sol   # Main protocol contract
│   ├── OrderMixin.sol                 # Core order logic from 1inch
│   ├── OrderLib.sol                   # Order library from 1inch
│   ├── libraries/                     # Supporting libraries
│   ├── interfaces/                    # Contract interfaces
│   └── helpers/                       # Helper contracts
├── script/
│   ├── DeployLocal.s.sol              # Local deployment script
│   └── DeployMainnet.s.sol            # Mainnet deployment with CREATE3
├── test/                              # Test files
└── foundry.toml                       # Foundry configuration
```

## Dependencies

- Foundry/Forge for development and testing
- OpenZeppelin Contracts v5.1.0
- 1inch Solidity Utils v5.0.0
- Soldeer for dependency management

## Security Considerations

- This is a simplified version without pausing, whitelisting, or staking mechanisms
- Designed specifically for Bridge-Me-Not atomic swaps
- Always test thoroughly on testnets before mainnet deployment
- Audit recommended before production use

## Related Repositories

- **Main Protocol**: `../bmn-evm-contracts/` - CrossChainEscrowFactory and core contracts
- **1inch Source**: `../limit-order-protocol/` - Original 1inch protocol reference
- **Resolver**: `../bmn-evm-resolver/` - Resolver implementation
- **Token**: `../bmn-evm-token/` - BMN token contracts

## License

MIT

## Support

For issues or questions, please open an issue in this repository or contact the Bridge-Me-Not team.