# Test Plan for SimpleLimitOrderProtocol

## Current Status
The test file `test/SimpleLimitOrderProtocol.t.sol` has multiple broken tests that use non-existent methods. These need to be completely rewritten.

## Problems to Fix

### 1. Broken Library Methods
The following methods were hallucinated and don't exist:
- `MakerTraitsLib.setAllowPartialFills()` - doesn't exist
- `MakerTraitsLib.setExpiry()` - doesn't exist  
- `MakerTraitsLib.setAllowedSender()` - doesn't exist
- `MakerTraitsLib.setHasExtension()` - doesn't exist
- `MakerTraitsLib.setMakerAssetSuffix()` - doesn't exist
- `AddressLib.from()` - doesn't exist, should use `Address.wrap(uint256(uint160(addr)))`

### 2. How MakerTraits Actually Works
MakerTraits is a uint256 with bit flags and encoded values:
- **Bit 255**: NO_PARTIAL_FILLS_FLAG (1 = no partial fills, 0 = allow partial)
- **Bit 254**: ALLOW_MULTIPLE_FILLS_FLAG
- **Bit 252**: PRE_INTERACTION_CALL_FLAG
- **Bit 251**: POST_INTERACTION_CALL_FLAG
- **Bit 250**: NEED_CHECK_EPOCH_MANAGER_FLAG
- **Bit 249**: HAS_EXTENSION_FLAG
- **Bit 248**: USE_PERMIT2_FLAG
- **Bit 247**: UNWRAP_WETH_FLAG
- **Bits 120-159** (40 bits): Expiration timestamp
- **Bits 80-119** (40 bits): Nonce or epoch
- **Bits 0-79** (80 bits): Last 10 bytes of allowed sender address

To create MakerTraits with specific settings:
```solidity
// Example: Create traits with expiry and allowed sender
uint256 traits = 0;
traits |= (uint256(expiryTimestamp) << 120); // Set expiry
traits |= uint256(uint160(allowedSender)) & ((1 << 80) - 1); // Set allowed sender (last 10 bytes)
traits |= (1 << 249); // Set HAS_EXTENSION_FLAG if needed
MakerTraits makerTraits = MakerTraits.wrap(traits);
```

## Tests to Implement

### Phase 1: Core Functionality (Priority)
1. **testBasicOrderCreation**
   - Create a simple order with correct Address types
   - Verify order hash calculation
   - No special flags, just basic maker/taker assets

2. **testSimpleOrderFilling**
   - Create order, sign it, fill it completely
   - Verify token transfers
   - Check events emitted

3. **testPartialOrderFilling** 
   - Create order allowing partial fills (no NO_PARTIAL_FILLS_FLAG)
   - Fill 50%, then fill remaining 50%
   - Verify correct amounts transferred each time

4. **testOrderCancellation**
   - Create order, cancel it via cancelOrder()
   - Attempt to fill cancelled order
   - Should revert with OrderCancelled error

### Phase 2: Advanced Features
5. **testOrderWithExpiry**
   ```solidity
   uint256 traits = (uint256(block.timestamp + 1 hours) << 120);
   order.makerTraits = MakerTraits.wrap(traits);
   ```
   - Create expired order (timestamp in past)
   - Attempt to fill should revert with OrderExpired

6. **testPrivateOrder**
   ```solidity
   uint256 traits = uint256(uint160(allowedResolver)) & ((1 << 80) - 1);
   order.makerTraits = MakerTraits.wrap(traits);
   ```
   - Create order with specific allowed sender
   - Non-allowed sender should fail
   - Allowed sender should succeed

7. **testOrderWithFactoryExtension**
   ```solidity
   uint256 traits = (1 << 249) | (1 << 251); // HAS_EXTENSION_FLAG | POST_INTERACTION_CALL_FLAG
   order.makerTraits = MakerTraits.wrap(traits);
   ```
   - Add factory extension data
   - Verify postInteraction is called
   - Check factory receives correct parameters

### Phase 3: Security & Edge Cases
8. **testInvalidSignature**
   - Wrong signer
   - Malformed signature
   - Replay attack prevention

9. **testReentrancyProtection**
   - Attempt reentrancy via malicious token
   - Should be protected by checks-effects-interactions

10. **testOverflowProtection**
    - Large amounts that could overflow
    - Zero amounts
    - Boundary conditions

## Helper Functions Needed

```solidity
function createOrder(
    address maker,
    address makerAsset,
    address takerAsset,
    uint256 makingAmount,
    uint256 takingAmount,
    uint256 makerTraitsFlags
) internal pure returns (IOrderMixin.Order memory) {
    return IOrderMixin.Order({
        salt: uint256(keccak256(abi.encodePacked(maker, block.timestamp))),
        maker: Address.wrap(uint256(uint160(maker))),
        receiver: Address.wrap(uint256(uint160(maker))),
        makerAsset: Address.wrap(uint256(uint160(makerAsset))),
        takerAsset: Address.wrap(uint256(uint160(takerAsset))),
        makingAmount: makingAmount,
        takingAmount: takingAmount,
        makerTraits: MakerTraits.wrap(makerTraitsFlags)
    });
}

function signOrder(
    IOrderMixin.Order memory order,
    uint256 privateKey
) internal view returns (bytes32 r, bytes32 vs) {
    bytes32 orderHash = protocol.hashOrder(order);
    bytes32 domainSeparator = protocol.DOMAIN_SEPARATOR();
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, orderHash));
    
    (uint8 v, bytes32 r_, bytes32 s) = vm.sign(privateKey, digest);
    r = r_;
    vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
}
```

## Test Execution Strategy

1. **Start Fresh**: Delete current broken tests, keep only setup
2. **Incremental Development**: Implement Phase 1 first, ensure all pass
3. **Use Actual APIs**: Reference the actual library code, don't assume methods exist
4. **Test Coverage**: Aim for >90% coverage of SimpleLimitOrderProtocol
5. **Gas Optimization**: Run with --gas-report to identify expensive operations

## Commands for Next Session

```bash
# Clean start
rm test/SimpleLimitOrderProtocol.t.sol
forge test # Should have no tests

# Create new test file with proper implementation
# Start with Phase 1 tests only

# Run tests incrementally
forge test --match-test testBasicOrderCreation -vvv
forge test --match-test testSimpleOrderFilling -vvv

# Once Phase 1 complete
forge coverage

# Then proceed to Phase 2 and Phase 3
```

## Success Criteria
- [ ] All tests pass without any compilation errors
- [ ] No usage of non-existent methods
- [ ] Proper Address type construction using Address.wrap()
- [ ] Correct MakerTraits bit manipulation
- [ ] >90% code coverage
- [ ] Clear, maintainable test code
- [ ] Comprehensive edge case coverage