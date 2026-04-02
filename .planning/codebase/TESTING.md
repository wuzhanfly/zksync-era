# Testing Patterns

**Analysis Date:** 2026-04-02

## Test Framework

**Runners:**
- **Rust:** `#[test]` (standard library) and `#[tokio::test]` (async runtime)
- **TypeScript:** Jest (integration tests) and Vitest (high-level tests)

**Assertion Libraries:**
- **Rust:** `assert_matches` crate for pattern matching assertions
- **TypeScript:** Jest's built-in `expect()` API with custom matchers

**Run Commands:**

```bash
# Rust
cargo test                          # Run all Rust tests
cargo test --lib                    # Unit tests only
cargo test --test '*'               # Integration tests

# TypeScript Jest
jest run                            # Integration tests (ts-integration)

# TypeScript Vitest
vitest run                          # High-level tests
```

## Test File Organization

**Location Patterns:**

- **Rust unit/integration:** Co-located within source files or in dedicated `tests.rs` files
  - Files: `src/tests.rs`, `src/testonly.rs`, inline `#[test]` modules
  - Examples: `core/node/genesis/src/tests.rs`, `core/node/eth_sender/src/tests.rs`

- **TypeScript integration:** `core/tests/ts-integration/tests/`
  - File pattern: `*.test.ts`
  - Examples: `evm.test.ts`, `contracts.test.ts`, `api/web3.test.ts`

- **TypeScript high-level:** `core/tests/highlevel-test-tools/tests/`
  - File pattern: `*.test.ts`
  - Examples: `main-node-integration-test.test.ts`, `fees-test.test.ts`

## Test Structure

**Rust:**
```rust
#[tokio::test]
async fn test_name() {
    let pool = ConnectionPool::<Core>::test_pool().await;
    let mut conn = pool.connection().await.unwrap();
    insert_genesis_batch(&mut conn, &params).await.unwrap();
    assert!(!conn.blocks_dal().is_genesis_needed().await.unwrap());
}
```

**TypeScript Jest:**
```typescript
describe('Suite name', () => {
    let testMaster: TestMaster;
    let alice: ethers.Wallet;

    beforeAll(() => {
        testMaster = TestMaster.getInstance(__filename);
        alice = testMaster.mainAccount();
    });

    test('should do something', async () => {
        const result = await action(alice);
        await expect(result).toBeAccepted([feeCheck]);
    });
});
```

## Mocking

**Rust:**
- `MockClient` from `zksync_web3_decl::client` for Web3 client mocking
- `MockObjectStore` from `zksync_object_store` for storage mocking
- `MockOneshotExecutor` from `zksync_vm_executor::oneshot` for VM execution mocking
- Pattern: Trait-based mocking via `async_trait`

**TypeScript:**
- Jest matchers extended via `expect.extend()` in `jest-setup/add-matchers.ts`
- Custom matchers: `toBeAccepted()`, `toBeReverted()`
- `RetryProvider` for resilient test execution

## Fixtures and Factories

**Rust Test Utilities (`core/node/test_utils/`):**
- `create_l2_block(number)` - Creates L2 block headers
- `create_l1_batch(number)` - Creates L1 batch headers
- `default_l1_batch_env()` - Default batch environment
- `default_system_env()` - Default system environment
- `ConnectionPool::test_pool()` - Isolated test database pool
- `GenesisParams::mock()` - Mock genesis parameters

**TypeScript Test Utilities (`core/tests/ts-integration/src/`):**
- `TestMaster` - Singleton per suite; manages wallets, providers, fund collection
- `TestContextOwner` - Manages test lifecycle (setup/teardown, fund distribution)
- `RetryProvider` / `RetryableWallet` - Resilient wrappers with retry logic

**Test setup:**
```typescript
globalSetup: "src/jest-setup/global-setup.ts"
globalTeardown: "src/jest-setup/global-teardown.ts"
setupFilesAfterEnv: ["src/jest-setup/add-matchers.ts"]
```

**Test Data Builders (`core/node/api_server/src/testonly.rs`):**
- `StateBuilder` - Builds complex account/storage states
- Helper functions: `default_fee()`, balance fixtures

## Test Types

**Unit Tests (Rust):**
- Co-located with source code
- Examples: `core/node/fee_model/src/l1_gas_price/gas_adjuster/tests.rs`
- Pattern: `#[test]` with simple assertions

**Integration Tests (Rust):**
- Async with `#[tokio::test]`
- Full `ConnectionPool::test_pool()` with database schema
- Examples: Genesis initialization, block reversal, eth_sender operations

**Integration Tests (TypeScript):**
- Jest-based end-to-end contract and API tests
- Location: `core/tests/ts-integration/tests/`
- Timeout: 605 seconds
- Setup: Global `beforeAll` with `TestMaster` and funded wallets

**E2E Tests (Vitest):**
- Location: `core/tests/highlevel-test-tools/tests/`
- Timeout: 15 minutes
- Scope: Full chain startup, recovery, migration, gateway tests
- Orchestration: `createChainAndStartServer()`, `runIntegrationTests()`

## Common Patterns

**Error/Revert Testing:**
```typescript
await expect(txPromise).toBeReverted();
await expect(txPromise).toBeReverted([modifier1, modifier2]);
```

```rust
assert_matches!(result, Err(ErrorType::Expected));
```
