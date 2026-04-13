# Coding Conventions

**Analysis Date:** 2026-04-08

**Scope:** `core/` directory - Rust codebase covering `core/node/`, `core/lib/`, `core/bin/`

---

## Naming Patterns

**Files:**
- `snake_case` for all `.rs` files: `eth_tx_manager.rs`, `gas_adjuster.rs`, `block_reverter.rs`
- Subdirectories are `snake_case`: `event_processors/`, `network_aware/`, `l1_gas_price/`
- Test helpers in a `tester.rs` sibling file: `core/node/eth_sender/src/tester.rs`
- Public test utilities in `testonly.rs` modules: `core/node/api_server/src/web3/testonly.rs`

**Types (structs, enums, traits):**
- `PascalCase`: `EthTxManager`, `GasAdjuster`, `BoundEthInterface`, `OperatorType`
- Error types use `PascalCase` suffix `Error`: `EthSenderError`, `ContractCallError`, `DalError`

**Functions and methods:**
- `snake_case`: `calculate_fees`, `send_raw_tx`, `get_pending_block_base_fee_per_gas`
- Boolean helpers use `is_` or `has_` prefix: `is_retriable()`, `is_retryable()`
- Builder pattern: `MockSettlementLayer::builder().with_fee_history(...).build()`
- `for_tests()` static constructors on config types: `EthConfig::for_tests()`, `ContractsConfig::for_tests()`

**Variables:**
- `snake_case` throughout: `connection_pool`, `stop_receiver`, `blob_base_fee_per_gas`
- Lifetimes use short alphabetic names: `'_`, `'a`, `'de`

**Constants:**
- `SCREAMING_SNAKE_CASE`: `WAIT_CONFIRMATIONS`, `MAX_BASE_FEE_SAMPLES`, `SL_CHAIN_ID`
- Global metric registries: `pub(super) static METRICS: vise::Global<EthSenderMetrics> = vise::Global::new()`

**Module visibility:**
- Internal-only items: `pub(super)` for module siblings, `pub(crate)` for crate-internal sharing
- Examples: `pub(super) struct PubdataKind`, `pub(crate) struct OperationSkippingRestrictions`
- `pub` only for items that must be consumed externally

---

## Code Style

**Formatting:**
- `rustfmt` with workspace defaults (no custom config observed)
- Multi-line struct literals use trailing commas
- `use std::{...}` groups multiple std imports in one statement: `use std::{cmp::max, fmt}`

**Linting:**
- `#![warn(clippy::cast_lossless)]` seen in `core/lib/dal/src/lib.rs`
- `#[allow(clippy::too_many_arguments)]` used when constructors genuinely require many args
- `#[allow(clippy::enum_variant_names)]` applied to metrics label enums where names repeat intentionally

**Derives:**
- Minimum useful set: `#[derive(Debug)]` is almost universal for non-trivial types
- Serializable types: `#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]`
- Metrics labels: `#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, EncodeLabelSet, EncodeLabelValue)]`
- Error enums: `#[derive(Debug, thiserror::Error)]`

---

## Import Organization

**Order (observed convention):**
1. `std` imports, grouped in `use std::{...}`
2. Third-party crates (tokio, anyhow, async-trait, serde, vise)
3. Internal `zksync_*` crates
4. Local module imports via `use crate::` or `use super::`

**Examples from `core/node/eth_sender/src/eth_tx_manager.rs`:**
```rust
use std::{
    sync::Arc,
    time::{Duration, SystemTime},
};

use tokio::sync::watch;
use zksync_config::configs::eth_sender::{GasLimitMode, SenderConfig};
use zksync_dal::{Connection, ConnectionPool, Core, CoreDal};
use zksync_eth_client::{...};

use super::{metrics::METRICS, EthSenderError};
use crate::{
    abstract_l1_interface::{AbstractL1Interface, OperatorNonce, OperatorType, RealL1Interface},
    ...
};
```

**Path Aliases:**
- No `use ... as ...` aliases are common; full names are used
- Re-exports via `pub use self::{...}` in `lib.rs` files to flatten module hierarchy

---

## Error Handling

**Typed errors with `thiserror`:**
Domain-specific errors are defined with `#[derive(thiserror::Error)]` enums. Each variant uses `#[error("...")]` for messages and `#[from]` for wrapping lower-level errors:

```rust
// core/node/eth_sender/src/error.rs
#[derive(Debug, thiserror::Error)]
pub enum EthSenderError {
    #[error("Ethereum gateway error: {0}")]
    EthereumGateway(#[from] EnrichedClientError),
    #[error("Dal error: {0}")]
    Dal(#[from] DalError),
    #[error("Max base fee exceeded")]
    ExceedMaxBaseFee,
}

impl EthSenderError {
    pub fn is_retriable(&self) -> bool { ... }
}
```

**`anyhow::Result` for top-level tasks:**
The public `run()` method on all long-lived components returns `anyhow::Result<()>`:
```rust
pub async fn run(mut self, stop_receiver: watch::Receiver<bool>) -> anyhow::Result<()>
```

**Context enrichment with `anyhow`:**
`.context(...)` and `.with_context(|| ...)` are used throughout for human-readable error wrapping:
```rust
// core/node/block_reverter/src/lib.rs
let db = RocksDB::new(path).context("failed initializing RocksDB for Merkle tree")?;
fs::try_exists(merkle_tree_path).await.with_context(|| {
    format!("failed checking Merkle tree path at {merkle_tree_path:?}")
})?;
```

**`?` operator is standard** for propagating `Result` values; explicit `match` is used only when the retry-loop needs to inspect different `Ok`/`Err` branches.

**Retriable error classification:**
Errors implement `is_retriable()` / `is_retryable()` to allow caller loops to decide whether to `continue` or bail:
```rust
if error.is_retriable() {
    METRICS.l1_transient_errors.inc();
    continue;
}
```

**`unwrap()` usage:**
`unwrap()` is used in non-test production code mainly for:
1. Infallible invariants documented with comments or `expect("reason; qed")`
2. DAL calls inside run loops that should panic if the DB is unavailable at a fundamental level
`expect("...")` is preferred over bare `unwrap()` when an invariant needs explaining.

---

## Async Patterns

**Runtime:**
- `tokio` is the async runtime. Crates declare `tokio = { workspace = true, features = ["time"] }`.

**Graceful shutdown:**
The canonical shutdown pattern uses `tokio::sync::watch::Receiver<bool>`:
```rust
pub async fn run(mut self, mut stop_receiver: watch::Receiver<bool>) -> anyhow::Result<()> {
    loop {
        tokio::time::sleep(self.config.tx_poll_period).await;
        if *stop_receiver.borrow() {
            tracing::info!("Stop request received, eth_tx_manager is shutting down");
            break;
        }
        // ... work ...
    }
    Ok(())
}
```
For select-based loops (aggregator):
```rust
tokio::select! {
    _ = tokio::time::sleep(poll_period) => {},
    _ = stop_receiver.changed() => break,
}
```

**Async traits:**
`#[async_trait]` from the `async-trait` crate is used for all `async fn` in traits:
```rust
#[async_trait]
pub trait EthInterface: Sync + Send + fmt::Debug {
    async fn fetch_chain_id(&self) -> EnrichedClientResult<SLChainId>;
}
```
Traits that need dynamic dispatch require `+ 'static + Sync + Send`.

**Shared state:**
- `Arc<dyn Trait>` for shared read-only dependencies: `Arc<dyn TxParamsProvider>`, `Arc<dyn ObjectStore>`
- `Arc<RwLock<T>>` for mutable shared state (seen in tests and mock clients)
- `ConnectionPool<Core>` is passed by clone (cheap) into async tasks; a `Connection<'_, Core>` is obtained per-operation

**Connection tagging:**
```rust
pool.connection_tagged("eth_sender").await.unwrap()
```
Tags identify the component in DB metrics/logs.

---

## Logging

**Framework:** `tracing` crate with structured fields.

**Usage levels:**
- `tracing::info!` for lifecycle events: startup, shutdown, batch operations
- `tracing::warn!` for recoverable errors and transient failures
- `tracing::debug!` for polling loops and progress checks
- `tracing::error!` called inside `IntoResponse` implementations for HTTP error observability

**Structured logging examples:**
```rust
tracing::info!(
    "Resending {operator_type:?} tx {} (nonce {}) at block {current_block} \
    with base_fee_per_gas {base_fee_per_gas:?}",
    tx.id, nonce,
);
tracing::warn!("eth_sender error {:?}", error);
```

**`#[tracing::instrument]` attribute:**
Used on key methods to provide automatic span context:
```rust
#[tracing::instrument(skip(self))]
pub async fn submit_attestation(...)
```

**Observability setup:**
`core/lib/vlog/` provides `ObservabilityBuilder` that configures `tracing_subscriber` layers for log format (JSON / plaintext), Sentry integration, and OpenTelemetry export.

---

## Metrics

**Framework:** `vise` crate (custom Prometheus wrapper).

**Pattern - declare a struct, register a global:**
```rust
// core/node/eth_sender/src/metrics.rs
#[derive(Debug, Metrics)]
#[metrics(prefix = "server_eth_sender")]
pub(super) struct EthSenderMetrics {
    pub transaction_resent: Counter,
    pub l1_tx_mined_latency: Family<TransactionType, Histogram<Duration>>,
    ...
}

#[vise::register]
pub(super) static METRICS: vise::Global<EthSenderMetrics> = vise::Global::new();
```

**Label enums** implement `EncodeLabelSet + EncodeLabelValue`:
```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, EncodeLabelSet, EncodeLabelValue)]
#[metrics(label = "type", rename_all = "snake_case")]
pub(super) enum TransactionType { Eip1559, Eip4844 }
```

---

## Module Design

**Structure per crate:**
```
src/
  lib.rs          # re-exports public API, declares mod tree
  error.rs        # domain Error enum
  metrics.rs      # vise metrics struct + static
  <component>.rs  # core logic
  node/           # WiringLayer + Task impls for node_framework
    mod.rs
    <layer>.rs
  tests.rs        # #[cfg(test)] integration tests
  tester.rs       # #[cfg(test)] test harness struct
```

**Exports:**
`lib.rs` re-exports with `pub use self::{...}` to expose only the public surface.
Internal types stay `pub(super)` or `pub(crate)`.

**`node/` subdirectory convention:**
Components that integrate with `node_framework` place `WiringLayer` and `Task` implementations under `src/node/`. This keeps framework wiring separate from domain logic.

**Comments:**
- Module-level doc comments (`//!`) describe the purpose of a crate/module
- Struct and trait doc comments (`///`) explain invariants and usage intent
- Inline `//` comments explain non-obvious logic (e.g., retry loop behavior)
- BSC-specific additions use Chinese comments: `// 网络感知模块`, `// BSC 优化的 Gas Price Provider`

---

## BSC Fork Conventions

- BSC-specific code lives in `core/node/eth_sender/src/network_aware/` and `src/eth_fees_oracle.rs`
- Chinese-language comments mark BSC-added code for traceability
- Network type is detected at runtime via `L1_CHAIN_ID` env var (see `detect_network_type_from_env()`)
- New structs follow existing naming: `BscGasPriceProvider`, `BscFeeConfig`, `NetworkAwareFeesOracle`

---

*Convention analysis: 2026-04-08*
