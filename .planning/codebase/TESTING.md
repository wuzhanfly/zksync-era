# Testing Patterns

**Analysis Date:** 2026-04-08

**Scope:** `core/` directory - Rust test suite in `core/node/` and `core/lib/`

---

## Test Framework

**Runner:**
- Rust's built-in `#[test]` and `#[tokio::test]` via the `tokio` runtime
- No separate test runner binary; tests live in the crate they test

**Assertion Libraries:**
- `assert_matches` crate: `assert_matches!(value, Pattern)` for enum variant matching
- Standard `assert_eq!`, `assert_ne!`, `assert!` macros
- No `proptest` or `quickcheck` observed

**Parameterized Tests:**
- `test-casing` crate for data-driven tests:
  ```rust
  #[test_casing(4, Product(([false, true], COMMITMENT_MODES)))]
  #[test_log::test(tokio::test)]
  async fn confirm_many(aggregator_operate_4844_mode: bool, commitment_mode: L1BatchCommitmentMode)
  ```
  - `Product((...))` creates a Cartesian product of parameter sets
  - The count argument must match the number of cases

**Logging in tests:**
- `test-log` crate: `#[test_log::test(tokio::test)]` wraps `tokio::test` and initializes `tracing` subscriber
- Used on all async integration tests so log output is visible during test runs

**Run Commands:**
```bash
cargo test -p zksync_eth_sender          # Run all tests in a specific crate
cargo test -p zksync_eth_sender -- confirm_many  # Run a single test by name
cargo test                               # Run all workspace tests (slow)
cargo nextest run                        # If nextest is available (faster)
```

**Key Dev Dependencies:**
Seen across `core/node/*/Cargo.toml`:
```toml
[dev-dependencies]
test-casing.workspace = true
test-log.workspace = true
assert_matches.workspace = true
zksync_node_test_utils.workspace = true
zksync_web3_decl.workspace = true       # For MockClient
zksync_eth_signer.workspace = true      # For PrivateKeySigner in tests
```

---

## Test File Organization

**Location pattern:** Tests are co-located in the same crate, not in a separate `tests/` directory.

Two common patterns:
1. **`tests.rs` + `tester.rs` siblings** (heavy integration tests):
   ```
   core/node/eth_sender/src/
     lib.rs
     tests.rs        # actual #[test] fns, guarded by #[cfg(test)]
     tester.rs       # EthSenderTester harness, guarded by #[cfg(test)]
   ```
2. **`tests/` subdirectory with `mod.rs`** (for large test suites):
   ```
   core/node/eth_watch/src/tests/
     mod.rs          # test functions
     client.rs       # FakeEthClientData mock
   ```
3. **Inline `#[cfg(test)] mod tests { ... }`** for small unit tests within a file

**`testonly` modules** (public test utilities for other crates):
```
core/node/api_server/src/web3/testonly.rs   # TestServerBuilder, create_test_tx_sender
core/node/api_server/src/testonly.rs        # mock_execute_transaction, store_custom_l2_block
core/node/node_sync/src/testonly.rs
core/node/state_keeper/src/testonly.rs
```
These are declared as `pub mod testonly;` in `lib.rs` without `#[cfg(test)]` so they are available to other crates' test suites.

---

## Test Structure

**Async test boilerplate:**
```rust
#[test_log::test(tokio::test)]
async fn my_test_name() -> anyhow::Result<()> {
    let connection_pool = ConnectionPool::<Core>::test_pool().await;
    let mut tester = EthSenderTester::new(
        connection_pool.clone(),
        vec![10; 100],   // base fee history
        false,           // non_ordering_confirmations
        true,            // aggregator_operate_4844_mode
        L1BatchCommitmentMode::Rollup,
        SettlementLayer::L1(10.into()),
    )
    .await;

    // arrange
    let batch = TestL1Batch::sealed(&mut tester).await;
    batch.save_commit_tx(&mut tester).await;

    // act
    tester.run_eth_sender_tx_manager_iteration().await;

    // assert
    tester.assert_just_sent_tx_count_equals(1).await;
    Ok(())
}
```

**Simple sync unit tests (no DB/network):**
```rust
#[test]
fn median() {
    assert_eq!(GasStatisticsInner::new(5, 5, [6, 4, 7, 8, 4]).median(), 6);
}
```

**Parameterized tests with `test_casing`:**
```rust
const COMMITMENT_MODES: [L1BatchCommitmentMode; 2] = [
    L1BatchCommitmentMode::Rollup,
    L1BatchCommitmentMode::Validium,
];

#[test_casing(2, COMMITMENT_MODES)]
#[test_log::test(tokio::test)]
async fn resend_each_block(commitment_mode: L1BatchCommitmentMode) -> anyhow::Result<()> { ... }

// Cartesian product:
#[test_casing(4, Product(([false, true], COMMITMENT_MODES)))]
#[test_log::test(tokio::test)]
async fn confirm_many(blob_mode: bool, commitment_mode: L1BatchCommitmentMode) -> anyhow::Result<()> { ... }
```

---

## Mocking

**Mock Ethereum Client (`MockSettlementLayer`):**
Located in `core/lib/eth_client/src/clients/mock.rs`. Builder pattern for construction:
```rust
let gateway = MockSettlementLayer::builder()
    .with_fee_history(
        std::iter::repeat_with(|| BaseFees { base_fee_per_gas: 1, ... })
            .take(WAIT_CONFIRMATIONS as usize)
            .chain(history)
            .collect(),
    )
    .with_non_ordering_confirmation(false)
    .with_call_handler(move |call, _block_id| {
        // Return mock ABI-encoded response
        crate::tests::mock_multicall_response(call)
    })
    .build();
```
`MockSettlementLayer` stores internal state behind `Arc<RwLock<MockSettlementLayerInner>>`, so it can be cloned and shared.

**`MockClient` from `zksync_web3_decl`:**
Lower-level JSON-RPC mock used for unit tests of client wrappers.

**`FakeEthClientData` / `MockEthClient`:**
Used in `eth_watch` tests (`core/node/eth_watch/src/tests/client.rs`):
```rust
pub struct FakeEthClientData {
    transactions: HashMap<u64, Vec<Log>>,
    last_finalized_block_number: u64,
    chain_id: SLChainId,
    // ...
}

// Wrapped in Arc<RwLock<...>> for shared mutable state:
#[derive(Clone)]
pub struct MockEthClient {
    inner: Arc<RwLock<FakeEthClientData>>,
}
```

**`MockObjectStore`:**
```rust
let object_store = MockObjectStore::arc();
// MockObjectStore is from zksync_object_store
```
Used for testing components that read/write blobs (proofs, snapshots).

**`MockOneshotExecutor`:**
Used in API server tests to mock VM execution results without running a real VM:
```rust
use zksync_vm_executor::oneshot::MockOneshotExecutor;
let executor = MockOneshotExecutor::default();
// or with responses:
executor.set_tx_responses(vec![...]);
```

**`AbstractL1Interface` trait for testing `EthTxManager`:**
The production code depends on `Box<dyn AbstractL1Interface>`. Tests inject a mock via `EthSenderTester` which wires `MockSettlementLayer` through this trait boundary.

**What to mock:**
- External services: Ethereum/BSC RPC client, object store (blobs)
- VM execution (via `MockOneshotExecutor`)
- Configuration structs via `for_tests()` factory methods

**What NOT to mock:**
- The database (`ConnectionPool<Core>`): real PostgreSQL is used via `ConnectionPool::test_pool()`
- Internal business logic in the component under test

---

## Fixtures and Factories

**`ConnectionPool::test_pool()`:**
Returns a `ConnectionPool<Core>` connected to a real PostgreSQL instance (configured via env vars in CI). Every async integration test creates its own pool.

**Config `for_tests()` factories:**
All major config types expose `pub fn for_tests() -> Self` returning sensible defaults:
```rust
let eth_sender_config = EthConfig::for_tests();
let contracts_config = ContractsConfig::for_tests();
let web3_config = Web3JsonRpcConfig::for_tests();
let state_keeper_config = StateKeeperConfig::for_tests();
let wallets = Wallets::for_tests();
```

**`zksync_node_test_utils` crate (`core/node/test_utils/src/lib.rs`):**
Shared helper functions:
```rust
pub fn create_l1_batch(number: u32) -> L1BatchHeader
pub fn create_l2_block(number: u32) -> L2BlockHeader
pub fn create_l2_transaction(input_data: Vec<u8>, factory_deps: Vec<Vec<u8>>) -> L2Tx
pub fn l1_batch_metadata_to_commitment_artifacts(meta: &L1BatchMetadata) -> L1BatchCommitmentArtifacts
pub async fn prepare_recovery_snapshot(...) -> SnapshotRecoveryStatus
```

**`mock_genesis_config()`:**
```rust
use zksync_node_genesis::mock_genesis_config;
let genesis = GenesisParams {
    config: mock_genesis_config(),
    ..Default::default()
};
```

**Data builder functions in test modules:**
Each test module defines local helpers for domain objects:
```rust
fn build_l1_tx(serial_id: u64, eth_block: u64) -> L1Tx { ... }
fn build_upgrade_tx(id: ProtocolVersionId) -> ProtocolUpgradeTx { ... }
pub(crate) fn default_l1_batch_metadata() -> L1BatchMetadata { ... }
pub(crate) fn l1_batch_with_metadata(header: L1BatchHeader) -> L1BatchWithMetadata { ... }
```

**`EthSenderTester` harness (`core/node/eth_sender/src/tester.rs`):**
Central test harness that wires all eth_sender dependencies together. Exposes helper methods for test scenarios:
```rust
pub struct EthSenderTester {
    pub conn: ConnectionPool<Core>,
    pub gateway: Box<MockSettlementLayer>,
    pub manager: EthTxManager,
    pub aggregator: EthTxAggregator,
    pub gas_adjuster: Arc<GasAdjuster>,
    // ...
}

impl EthSenderTester {
    pub async fn new(pool, history, ...) -> Self
    pub async fn run_eth_sender_tx_manager_iteration(&mut self)
    pub async fn assert_just_sent_tx_count_equals(&self, count: usize)
    pub async fn assert_inflight_txs_count_equals(&self, count: usize)
    pub async fn seal_l1_batch(&mut self)
    pub async fn commit_l1_batch(&mut self, number: L1BatchNumber, confirm: bool) -> H256
}
```

**`TestL1Batch` wrapper (`core/node/eth_sender/src/tester.rs`):**
Semantic wrapper for driving test scenarios through the batch lifecycle:
```rust
let batch = TestL1Batch::sealed(&mut tester).await;
batch.save_commit_tx(&mut tester).await;
batch.commit(&mut tester, /*confirm=*/true).await;
batch.execute_commit_tx(&mut tester).await;
batch.assert_commit_tx_just_sent(&mut tester).await;
```

---

## Coverage

**Requirements:** No enforced coverage thresholds found.

**View Coverage:**
```bash
cargo llvm-cov --workspace --lcov --output-path lcov.info
```
(Standard Rust LLVM coverage; no project-specific config observed.)

---

## Test Types

**Unit Tests (sync, no I/O):**
Small functions tested inline with `#[cfg(test)] mod tests { ... }`. Examples:
- `GasStatisticsInner::median()` in `core/node/fee_model/src/l1_gas_price/gas_adjuster/tests.rs`
- Gas price calculation logic in `core/node/eth_sender/src/network_aware/fees_oracle.rs`
- Network detector heuristics in `core/node/eth_sender/src/network_aware/network_detector.rs`

**Integration Tests (async, real DB):**
The dominant test style. Full component lifecycle using `ConnectionPool::test_pool()` and mock external interfaces. Examples:
- `core/node/eth_sender/src/tests.rs` - ~1000 lines, 30+ test functions covering EthTxManager and EthTxAggregator
- `core/node/eth_watch/src/tests/mod.rs` - event processor and priority op ingestion
- `core/node/api_server/src/web3/tests/` - HTTP and WebSocket JSON-RPC endpoint tests
- `core/node/block_reverter/src/tests.rs` - block reversion state machine

**Integration Tests (external processes, TypeScript):**
- `core/tests/ts-integration/` - Jest-based end-to-end tests using ethers.js against a running node
- `core/tests/recovery-test/` - snapshot recovery scenario
- `core/tests/upgrade-test/` - protocol upgrade scenario
- `core/tests/loadnext/` - load testing tool (not CI unit tests)

**Benchmarks:**
- `core/tests/vm-benchmark/benches/` - Criterion benchmarks for VM performance

---

## Common Patterns

**Async Testing:**
```rust
#[test_log::test(tokio::test)]
async fn component_does_x() -> anyhow::Result<()> {
    let pool = ConnectionPool::<Core>::test_pool().await;
    let mut tester = ComponentTester::new(pool, ...).await;

    // arrange - set up state via tester helpers
    tester.seed_some_data().await;

    // act - drive one iteration of the component's loop
    tester.run_one_iteration().await;

    // assert - check observable state
    assert_eq!(tester.count_things_in_db().await, expected);
    Ok(())
}
```

**Error Testing:**
```rust
use assert_matches::assert_matches;

let result = component.do_something_that_may_fail().await;
assert_matches!(result, Err(EthSenderError::ExceedMaxBaseFee));

// or for Ok variants:
assert_matches!(result, Ok(Some(_)));
```

**Stop signal in tests:**
Background tasks spawned in tests use `watch::channel(false)`:
```rust
let (stop_sender, stop_receiver) = watch::channel(false);
let handle = tokio::task::spawn(async move {
    task.run(stop_receiver).await.unwrap()
});
// ... test logic ...
stop_sender.send(true).unwrap();
handle.await.unwrap();
```

**Advancing mock chain state:**
```rust
tester.gateway.advance_block_number(3, EthTxFinalityStatus::Finalized);
tester.gas_adjuster.keep_updated().await?;
```

**Testing with `MockSettlementLayer` call handler:**
```rust
.with_call_handler(move |call, _block_id| {
    assert_eq!(call.to, Some(contracts_config.l1.multicall3_addr));
    mock_multicall_response(call)
})
```
The call handler is a closure that returns `ethabi::Token` for any `eth_call` the component makes.

---

*Testing analysis: 2026-04-08*
