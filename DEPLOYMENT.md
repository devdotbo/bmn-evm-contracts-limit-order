# SimpleLimitOrderProtocol Deployment Guide

## Pre-Deployment Checklist

### Environment Setup
- [ ] Verify `.env` file exists in parent directory with:
  - [ ] `DEPLOYER_PRIVATE_KEY` - Valid mainnet deployer private key
  - [ ] `OPTIMISM_RPC` - Optimism RPC endpoint
  - [ ] `BASE_RPC` - Base RPC endpoint
  - [ ] `OPTIMISM_EXPLORER_API_KEY` - For contract verification
  - [ ] `BASE_EXPLORER_API_KEY` - For contract verification

### Wallet Requirements
- [ ] Deployer wallet has sufficient ETH on Optimism (~0.01 ETH)
- [ ] Deployer wallet has sufficient ETH on Base (~0.01 ETH)
- [ ] Record deployer address: ________________________

### Pre-Deployment Verification
- [ ] All tests passing: `forge test`
- [ ] Contract compiles without warnings: `forge build`
- [ ] Gas report reviewed: `forge test --gas-report`

## Deployment Process

### 1. Deploy to Optimism

```bash
# Source environment variables
source ../.env

# Deploy to Optimism mainnet
forge script script/DeployMainnet.s.sol \
    --rpc-url $OPTIMISM_RPC \
    --broadcast \
    --verify \
    --etherscan-api-key $OPTIMISM_EXPLORER_API_KEY \
    -vvvv
```

Expected output:
- Predicted address: `0x...` (same on both chains via CREATE3)
- Deployed address: `0x...`
- Transaction hash: `0x...`

### 2. Deploy to Base

```bash
# Deploy to Base mainnet (same address as Optimism)
forge script script/DeployMainnet.s.sol \
    --rpc-url $BASE_RPC \
    --broadcast \
    --verify \
    --etherscan-api-key $BASE_EXPLORER_API_KEY \
    -vvvv
```

### 3. Post-Deployment Verification

#### Optimism
- [ ] Contract deployed at predicted address
- [ ] Contract verified on Optimism Explorer
- [ ] DOMAIN_SEPARATOR() callable
- [ ] hashOrder() works with test order

#### Base
- [ ] Contract deployed at SAME address as Optimism
- [ ] Contract verified on Base Explorer
- [ ] DOMAIN_SEPARATOR() callable
- [ ] hashOrder() works with test order

### 4. Integration Testing

#### Test Order Creation
```javascript
const testOrder = {
    salt: "0x1234...",
    maker: "0xTestMaker...",
    receiver: "0x0000...",
    makerAsset: "0xTokenAddress...",
    takerAsset: "0xTokenAddress...",
    makingAmount: "1000000000000000000",
    takingAmount: "500000000000000000",
    makerTraits: "0x..." // with POST_INTERACTION flag
};
```

#### Verify Factory Integration
- [ ] Create order with factory extension data
- [ ] Simulate fillOrder transaction
- [ ] Verify postInteraction would be called on factory

## Deployed Addresses

### Mainnet Deployments
| Network | SimpleLimitOrderProtocol | CrossChainEscrowFactory | CREATE3 Factory |
|---------|-------------------------|------------------------|-----------------|
| Optimism | `TBD` | `0xB916C3edbFe574fFCBa688A6B92F72106479bD6c` | `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` |
| Base | `TBD` | `0x2B2d52Cf0080a01f457A4f64F41cbca500f787b1` | `0x7B9e9BE124C5A0E239E04fDC93b66ead4e8C669d` |

### WETH Addresses
- Optimism: `0x4200000000000000000000000000000000000006`
- Base: `0x4200000000000000000000000000000000000006`

## Monitoring Setup

### Events to Monitor
1. `OrderFilled(bytes32 indexed orderHash, uint256 makingAmount)`
2. Factory's `PostInteractionCalled` events
3. Factory's `EscrowCreated` events

### Monitoring Tools
- Set up event listeners on both chains
- Configure alerts for failed transactions
- Monitor gas prices for optimal filling

## Emergency Procedures

### If Deployment Fails
1. Check deployer balance
2. Verify RPC endpoint is working
3. Check CREATE3 factory is accessible
4. Review transaction error message

### If Wrong Address Deployed
- CREATE3 ensures same address on all chains
- If mismatch, verify same SALT and deployer used

### Rollback Plan
- No rollback needed for immutable contracts
- Deploy new version with different SALT if critical bug found

## Security Checklist

- [ ] No hardcoded private keys in code
- [ ] All test files excluded from deployment
- [ ] Contract bytecode matches local build
- [ ] No admin functions that could be exploited
- [ ] Interactions with factory are permissionless

## Resolver Integration

After deployment, update resolver to:
1. Point to new SimpleLimitOrderProtocol addresses
2. Create orders with proper MakerTraits flags
3. Include factory extension data in orders
4. Call fillOrder instead of factory methods directly

## Support Contacts

- Bridge-Me-Not Team: [Contact info]
- 1inch Protocol Docs: https://docs.1inch.io/
- CREATE3 Factory: https://github.com/ZeframLou/create3-factory