# Bridge-Me-Not Limit Order Protocol

## 🚀 Status: DEPLOYED & LIVE ON MAINNET

**Deployment Date**: January 6, 2025  
**Deployer**: `0x5f29827e25dc174a6A51C99e6811Bbd7581285b0`  
**Status**: ✅ Fully deployed and verified on Optimism and Base mainnet

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

### SimpleLimitOrderProtocol (Deployed ✅)

| Network | Contract Address | Block Explorer | Deployment Block | Status |
|---------|-----------------|----------------|------------------|--------|
| **Optimism** | `0x44716439C19c2E8BD6E1bCB5556ed4C31dA8cDc7` | [View on Optimistic Etherscan](https://optimistic.etherscan.io/address/0x44716439c19c2e8bd6e1bcb5556ed4c31da8cdc7) | 139447565 | ✅ Verified |
| **Base** | `0x1c1A74b677A28ff92f4AbF874b3Aa6dE864D3f06` | [View on Basescan](https://basescan.org/address/0x1c1a74b677a28ff92f4abf874b3aa6de864d3f06) | 33852257 | ✅ Verified |

**Note**: Different addresses were deployed using TestDeploy script. For same address deployment across chains, use DeployMainnet.s.sol with production salt.

## Deployment Details

### Technical Specifications
- **Solidity Version**: 0.8.23
- **Optimizer Runs**: 1,000,000
- **Contract Size**: ~23KB
- **Deployment Gas**: ~4.66M gas
- **Constructor Argument**: WETH (`0x4200000000000000000000000000000000000006`)

### Domain Separators
- **Optimism**: `0x628b04420e4d169a5ddf0120e151ac7498e6213f680c14311e2ead62b73e040a`
- **Base**: `0x16fd7f97521d06dd998effb9441cb01d062468b52baa9447227215f9eecd225f`

### Deployment Transactions
- **Base Deployment**: Block 33852257 (January 6, 2025)
- **Optimism Deployment**: Block 139447565 (January 6, 2025)
- **Total Cost**: < 0.001 ETH per chain

### Indexer Configuration
For indexers and event monitoring, start scanning from:
- **Base**: Block `33852257`
- **Optimism**: Block `139447565`

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

## Integration Guide

### Connecting to Deployed Contracts

```javascript
// Contract addresses
const PROTOCOL_OPTIMISM = "0x44716439C19c2E8BD6E1bCB5556ed4C31dA8cDc7";
const PROTOCOL_BASE = "0x1c1A74b677A28ff92f4AbF874b3Aa6dE864D3f06";

// Factory addresses (already deployed)
const FACTORY_OPTIMISM = "0xB916C3edbFe574fFCBa688A6B92F72106479bD6c";
const FACTORY_BASE = "0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1";

// Connect to protocol
const protocol = await ethers.getContractAt(
    "SimpleLimitOrderProtocol",
    PROTOCOL_BASE // or PROTOCOL_OPTIMISM
);
```

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

## Monitoring & Events

### Key Events to Monitor

```solidity
// Order filled event
event OrderFilled(
    bytes32 indexed orderHash,
    uint256 makingAmount,
    uint256 takingAmount
);

// Order cancelled event  
event OrderCancelled(bytes32 indexed orderHash);

// Factory PostInteraction event
event PostInteractionCalled(
    address indexed taker,
    uint256 makingAmount,
    uint256 takingAmount,
    bytes32 orderHash
);
```

### Event Monitoring Example

```javascript
// Monitor OrderFilled events
protocol.on("OrderFilled", (orderHash, makingAmount, takingAmount) => {
    console.log(`Order ${orderHash} filled:`);
    console.log(`  Making: ${makingAmount}`);
    console.log(`  Taking: ${takingAmount}`);
});

// Monitor factory interactions
factory.on("PostInteractionCalled", (taker, makingAmount, takingAmount, orderHash) => {
    console.log(`Factory triggered for order ${orderHash}`);
    console.log(`  Taker: ${taker}`);
    console.log(`  Cross-chain swap initiated`);
});
```

### Query Historical Events

```javascript
// Get recent OrderFilled events
const filter = protocol.filters.OrderFilled();
const events = await protocol.queryFilter(filter, -1000); // Last 1000 blocks
```

## Testing

The project includes a comprehensive test suite with **13 passing tests** covering all critical functionality, security aspects, and edge cases of the SimpleLimitOrderProtocol.

### Test Coverage Areas

- **Core Order Functionality**: Order creation, filling, partial fills, and cancellation
- **Signature Validation**: EIP-712 signature verification and security checks
- **Cross-Chain Integration**: Factory extension data handling and postInteraction callbacks
- **Advanced Features**: Predicate validation, epoch management, and remaining amount tracking
- **Security**: Reentrancy protection, access controls, and edge case handling
- **Gas Optimization**: Efficient order processing with gas costs under 150k for standard fills

### Running Tests

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvv

# Run specific test file
forge test --match-path test/SimpleLimitOrderProtocol.t.sol

# Run specific test function
forge test --match-test testOrderFilling

# Run with gas reporting
forge test --gas-report
```

### Test Documentation

For detailed information about the test suite, see **TEST.md** for comprehensive testing documentation including:
- Test implementation guide and specifications
- Testing philosophy and strategic approach
- Gas reports and performance metrics
- Architecture details and helper functions

### Key Test Scenarios

1. **Standard Order Flow**: Complete lifecycle from creation to fulfillment
2. **Partial Fills**: Multiple partial fills with accurate accounting
3. **Cross-Chain Escrow**: Factory callback integration for atomic swaps
4. **Security Validations**: Invalid signatures, expired orders, unauthorized access
5. **Edge Cases**: Zero amounts, duplicate fills, reentrancy attempts

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

## Production Checklist

### ✅ Completed
- [x] Deploy SimpleLimitOrderProtocol to Base mainnet
- [x] Deploy SimpleLimitOrderProtocol to Optimism mainnet  
- [x] Verify contracts on block explorers
- [x] Document deployment addresses
- [x] Create comprehensive test suite (13/13 passing)
- [x] Integration tests with mock factory

### 🔄 In Progress
- [ ] Test cross-chain order with factory extension on testnets
- [ ] Update resolver to use LimitOrderProtocol
- [ ] Execute end-to-end atomic swap test on mainnet
- [ ] Set up monitoring dashboard for events
- [ ] Create example scripts for order creation/filling

### 📋 Next Steps
1. **Testnet Testing**: Deploy to Optimism Sepolia and Base Sepolia for integration testing
2. **Resolver Update**: Modify resolver to interact with LimitOrderProtocol instead of factory directly
3. **Live Testing**: Execute small-value test swaps on mainnet
4. **Monitoring Setup**: Deploy event monitoring and alerting system
5. **Documentation**: Create detailed integration examples and tutorials

## Troubleshooting

### Common Issues

**Order Not Filling**
- Check maker has sufficient token balance
- Verify token approval to protocol address
- Ensure order hasn't expired (check MakerTraits bits 80-119)
- Confirm signature is valid

**Factory Not Triggered**
- Verify POST_INTERACTION_CALL_FLAG (bit 251) is set in MakerTraits
- Check factory address in extension data
- Ensure HAS_EXTENSION_FLAG (bit 249) is set if using extensions

**Cross-Chain Issues**
- Verify factory addresses match on both chains
- Check destination chain ID in extension data
- Ensure resolver has funds on destination chain

## License

MIT

## Support

For issues or questions, please open an issue in this repository or contact the Bridge-Me-Not team.

## Acknowledgments

- 1inch Protocol team for the original Limit Order Protocol
- Foundry team for excellent development tools
- OpenZeppelin for secure contract libraries