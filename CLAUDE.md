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
# Run all tests (currently 13 passing tests)
forge test

# Run tests with verbosity for debugging
forge test -vvv

# Run specific test file
forge test --match-path test/SimpleLimitOrderProtocol.t.sol

# Run specific test by name
forge test --match-test testOrderFilling

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage

# Troubleshooting stack too deep errors
# Enable via-ir compilation if encountering stack issues
forge test --via-ir
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
- IR compilation: Enabled (--via-ir) to resolve stack too deep errors
- Dependency management: Soldeer (dependencies stored in `dependencies/` directory)
- Remappings configured in `foundry.toml`

## Implementation Notes

### MakerTraits Bit Layout
The MakerTraits uint256 packs multiple order parameters using specific bit positions:
- **Bits 0-79**: Reserved for other flags and parameters
- **Bits 80-119**: Expiration timestamp (40 bits) - NOT bits 120-159 as might be expected
- **Bits 120-255**: Additional parameters including nonce suffix

Example of setting expiration:
```solidity
uint256 makerTraits = uint256(expiration) << 80;
```

### Address Type Handling
The codebase uses the 1inch AddressLib pattern with wrapped Address types:
```solidity
import {Address, AddressLib} from "../solidity-utils/contracts/libraries/AddressLib.sol";

// Wrapping native address to Address type
Address wrappedAddr = Address.wrap(someAddress);

// Using AddressLib for conversions
address nativeAddr = AddressLib.get(wrappedAddr);
```

### Test Architecture Patterns

#### Mock Contracts
Tests use mock implementations for external dependencies:
- `MockERC20`: Simple ERC20 token for testing
- `MockFactory`: Simulates CrossChainEscrowFactory behavior
- `MockResolver`: Simulates resolver interactions

#### Test Setup Structure
```solidity
function setUp() public {
    // 1. Deploy protocol contract
    protocol = new SimpleLimitOrderProtocol(WETH);
    
    // 2. Deploy mock tokens
    srcToken = new MockERC20("Source", "SRC");
    dstToken = new MockERC20("Dest", "DST");
    
    // 3. Set up test accounts (alice = maker, bob = taker)
    // 4. Fund accounts with tokens
    // 5. Set unlimited approvals
}
```

#### Order Creation Pattern
Orders require careful construction with proper encoding:
```solidity
IOrderMixin.Order memory order = IOrderMixin.Order({
    salt: uint256(keccak256("unique-salt")),
    maker: Address.wrap(alice),
    receiver: Address.wrap(address(0)), // defaults to taker
    makerAsset: Address.wrap(address(srcToken)),
    takerAsset: Address.wrap(address(dstToken)),
    makingAmount: 1000 * 1e18,
    takingAmount: 500 * 1e18,
    makerTraits: makerTraits
});
```

### Common Troubleshooting

#### Stack Too Deep Errors
If encountering "Stack too deep" errors during compilation:
1. Enable IR compilation in foundry.toml: `viaIR = true`
2. Or use command line flag: `forge build --via-ir`
3. Consider refactoring complex functions into smaller helpers

#### Test Execution Tips
- Use `--match-path` for running specific test files
- Use `--match-test` with regex patterns for test filtering
- Add `-vvvv` for maximum verbosity when debugging failures
- Check gas usage with `--gas-report` to identify optimization opportunities

#### Extension Data Encoding
When testing with factory extensions, ensure proper ABI encoding:
```solidity
bytes memory extension = abi.encode(
    factory,
    destinationChainId,
    destinationToken,
    destinationReceiver,
    timelocks,
    hashlock
);
```