# Architecture

**Analysis Date:** 2026-04-08

## Pattern Overview

**Overall:** Component-based service framework with explicit dependency injection via a "wiring layer" pattern. The node is assembled by composing independent `WiringLayer` units into a `ZkStackService`. Each layer registers `Task` workers and `Resource` interfaces (shared via trait objects) consumed by other layers.

**Key Characteristics:**
- All long-running work runs as independent async `Task`s managed by `ZkStackService`
- Components communicate through PostgreSQL (DAL) as the shared state bus — not direct in-process calls
- Separation between `core/lib/` (pure libraries with no node-wiring code) and `core/node/` (node-integrated components with `pub mod node` wiring modules)
- Three distinct executables share most library code: main node (`zksync_server`), external node (`external_node`), and TEE prover (`zksync_tee_prover`)
- BSC-specific adaptations are isolated to `core/node/eth_sender/src/network_aware/` and `core/node/fee_model/src/l1_gas_price/`

## Layers

**Binary / Entry Points:**
- Purpose: Parse CLI, load configuration, assemble the node using builder pattern
- Location: `core/bin/zksync_server/src/`, `core/bin/external_node/src/`
- Contains: `main.rs`, `node_builder.rs`, `components.rs`
- Depends on: `core/lib/node_framework`, all `core/node/*/src/node/` wiring modules
- Used by: Operators running the chain

**Node Framework:**
- Purpose: Dependency injection container and service lifecycle manager
- Location: `core/lib/node_framework/src/`
- Contains: `WiringLayer` trait, `Task` trait, `Resource` trait, `ZkStackService`, `ZkStackServiceBuilder`
- Depends on: Nothing beyond tokio/anyhow
- Used by: Every `core/node/*/src/node/` module

**Node Components (`core/node/`):**
- Purpose: Long-running daemon tasks that implement the zkStack protocol pipeline
- Location: `core/node/*/src/`
- Contains: Business logic + `pub mod node` (wiring adapter to register with framework)
- Depends on: `core/lib/` for types, DAL, eth_client; PostgreSQL for state
- Used by: Node builder wires them into `ZkStackService`

**Library Layer (`core/lib/`):**
- Purpose: Reusable, framework-independent crates — types, DAL, clients, VM, crypto
- Location: `core/lib/*/src/`
- Contains: Pure logic, trait definitions, data models
- Depends on: External crates only (no circular dependencies to node/)
- Used by: Both `core/node/` and `core/bin/`

## Data Flow

**L2 Transaction Lifecycle (main node):**

1. Client sends JSON-RPC → `core/node/api_server` (`EthNamespace`, `ZksNamespace`) receives it
2. `TxSender` in `core/node/api_server/src/tx_sender/` validates and inserts into `MempoolStore` (`core/lib/mempool`)
3. `MempoolFetcher` (`core/node/state_keeper`) polls the mempool and feeds to `StateKeeper`
4. `StateKeeper` (`core/node/state_keeper/src/keeper.rs`) executes txs via `BatchExecutor` (backed by `core/lib/multivm`)
5. After sealing criteria trigger (`core/node/state_keeper/src/seal_criteria/`), the L2 block/L1 batch is finalized
6. `StateKeeperPersistence` writes sealed batch data to PostgreSQL via `core/lib/dal`

**L1 Batch → L1 Settlement Pipeline:**

1. `MetadataCalculator` (`core/node/metadata_calculator`) reads sealed batches from DB, updates Merkle tree (RocksDB via `core/lib/zk_os_merkle_tree`), writes tree root back to DB
2. `CommitmentGenerator` (`core/node/commitment_generator`) reads batch + tree data, computes KZG commitments / pubdata hashes, writes `L1BatchCommitmentArtifacts` to DB
3. `DataAvailabilityDispatcher` (`core/node/da_dispatcher`) reads pubdata from DB, submits to the configured DA layer (Avail, Celestia, EigenDA, or calldata/blobs)
4. `EthTxAggregator` (`core/node/eth_sender`) reads committed batches from DB and groups them into aggregated L1 operations (commit / prove / execute)
5. `EthTxManager` (`core/node/eth_sender`) signs and submits the aggregated txs to BSC L1, handles resubmission with bumped fees, tracks finality in DB
6. `ConsistencyChecker` (`core/node/consistency_checker`) verifies committed batch data against L1 contract state

**L1 → L2 Priority Operations:**

1. `EthWatch` (`core/node/eth_watch`) polls BSC L1 (via `core/lib/eth_client`) for events from the diamond proxy contract
2. `PriorityOpsEventProcessor` writes priority ops to DB; `DecentralizedUpgradesEventProcessor` handles protocol upgrades
3. `StateKeeper` picks up priority ops from DB as it opens each new batch
4. BSC-specific: block range per query is limited to 5000 blocks (hardcoded in `core/node/eth_watch/src/lib.rs:218`)

**External Node Sync:**

1. External node runs `node_sync` (`core/node/node_sync`) which fetches L2 block data from main node via JSON-RPC
2. `ExternalIO` replays batches through the same `StateKeeper` / `BatchExecutor` pipeline
3. Tree and commitment are built identically, allowing independent verification

**Fee Computation:**

1. `GasAdjuster` (`core/node/fee_model/src/l1_gas_price/gas_adjuster/`) samples recent BSC blocks for `base_fee` and `blob_base_fee`
2. BSC fee_history API incompleteness is handled with padding/fallback logic in the same module
3. `BscGasPriceProvider` (`core/node/eth_sender/src/eth_fees_oracle.rs`) uses safety margins instead of EIP-1559 priority fees
4. `NetworkType` detector (`core/node/eth_sender/src/network_aware/network_detector.rs`) routes to legacy or EIP-1559 fee path based on chain ID

**State Management:**
- Canonical truth lives in PostgreSQL (via `core/lib/dal`)
- Merkle tree state is a RocksDB sidecar kept in sync by `MetadataCalculator`
- In-memory mempool (`MempoolStore`) is rebuilt from DB on restart
- Tokio `watch` channels pass stop signals and share reader handles (e.g., `AsyncTreeReader`)

## Key Abstractions

**`WiringLayer` / `Task` / `Resource`:**
- Purpose: Compose node services with explicit dependency declarations
- Examples: `core/node/state_keeper/src/node/`, `core/node/eth_sender/src/node/`, `core/node/metadata_calculator/src/node/`
- Pattern: Each `WiringLayer` implementation's `wire()` method constructs the component and registers it as a `Task`; resources are shared via `Arc<dyn Trait>`

**`StateKeeperIO` trait:**
- Purpose: Decouple batch production from the source of transactions (mempool vs. external sync)
- Examples: `core/node/state_keeper/src/io/mempool.rs` (main node), `core/node/node_sync/src/external_io.rs` (external node)
- Pattern: Trait object injected into `StateKeeper` at construction time

**`BatchExecutor` / `BatchExecutorFactory` traits:**
- Purpose: Execute transactions against VM state, independent of state keeper IO
- Examples: `core/lib/multivm/src/vm_instance.rs` (production), test doubles in `core/node/state_keeper/src/testonly/`
- Pattern: Factory pattern — `BatchExecutorFactory` spawns a `BatchExecutor` per batch

**Data Access Layer (DAL):**
- Purpose: Single typed interface to all PostgreSQL tables
- Examples: `core/lib/dal/src/blocks_dal.rs`, `core/lib/dal/src/transactions_dal.rs`, `core/lib/dal/src/eth_sender_dal.rs`
- Pattern: `ConnectionPool<Core>` → `Connection<Core>` → `CoreDal` trait provides typed DAL accessors; ~30 sub-DALs accessed via `connection.blocks_dal()`, etc.

**`EthClient` / `BoundEthInterface` traits:**
- Purpose: Typed L1 (BSC) interaction — call, send tx, query events
- Examples: `core/lib/eth_client/src/clients/http/`, `core/lib/eth_client/src/lib.rs`
- Pattern: Trait objects allow test doubles; `DynClient<L1>` / `DynClient<L2>` are type-tagged wrappers

**`DataAvailabilityClient` trait:**
- Purpose: Pluggable DA backends
- Examples: `core/node/da_clients/src/avail/`, `core/node/da_clients/src/celestia/`, `core/node/da_clients/src/eigen/`
- Pattern: Interface defined in `core/lib/da_client/`; concrete impls in `core/node/da_clients/`

**`L1BatchCommitment` / `L1BatchWithMetadata`:**
- Purpose: Typed representation of all data needed to commit a batch on L1
- Examples: `core/lib/types/src/commitment.rs`
- Pattern: Built by `CommitmentGenerator`, consumed by `EthTxAggregator` which encodes it into ABI calldata via `core/lib/l1_contract_interface/`

## Entry Points

**Main Node Binary:**
- Location: `core/bin/zksync_server/src/main.rs`
- Triggers: `zksync_server` executable; default components = `api,tree,eth,state_keeper,housekeeper,commitment_generator,da_dispatcher,vm_runner_protective_reads,consensus`
- Responsibilities: Parse config, construct `MainNodeBuilder`, call `build()` then `run()`

**External Node Binary:**
- Location: `core/bin/external_node/src/main.rs`
- Triggers: `external_node` executable
- Responsibilities: Same pattern; wires `ExternalNodeBuilder` which replaces `MempoolIO` with `ExternalIO`

**Block Reverter Tool:**
- Location: `core/bin/block_reverter/src/main.rs`, library at `core/node/block_reverter/`
- Responsibilities: Roll back DB state and Merkle tree to a prior L1 batch number for reorg recovery

**Genesis Generator:**
- Location: `core/bin/genesis_generator/src/main.rs`, library at `core/node/genesis/`
- Responsibilities: Initialize DB state from genesis config before first run

## Error Handling

**Strategy:** `anyhow::Result` propagation for all component-level errors. Fatal errors shut down the node; transient errors are logged and retried in polling loops.

**Patterns:**
- `EthWatch` distinguishes `EventProcessorError::Fatal` (returns `Err`, kills node) from `EventProcessorError::Transient` (logs, continues loop)
- `EthTxManager` retries stuck transactions with bumped gas prices using exponential backoff strategy stored in DB (`eth_tx_history`)
- DAL errors use `DalError`/`DalResult` wrappers that attach context (query, table) to `sqlx::Error`
- `CircuitBreaker` (`core/lib/circuit_breaker/`) halts the node on detected state inconsistencies

## Cross-Cutting Concerns

**Logging:** `tracing` crate throughout; spans named with component prefix (e.g., `#[tracing::instrument(name = "EthWatch::loop_iteration")]`). Configured via `core/lib/vlog/`.

**Metrics:** `vise` (Prometheus) metrics crate. Each component has `mod metrics` with a static `METRICS` instance. Shared metrics in `core/node/shared_metrics/`.

**Health Checks:** `ReactiveHealthCheck` + `HealthUpdater` pattern from `core/lib/health_check/`. Each component publishes its health status; aggregated by the HTTP health endpoint.

**Validation:** Input validation at API layer (`core/node/api_server/src/tx_sender/`) using configurable gas limits. Signature validation via `core/lib/crypto_primitives/`.

**Authentication:** No application-layer auth on JSON-RPC. L1 operator keys loaded from config (`Secrets`/`Wallets`); signing done in `core/lib/eth_signer/`.

---

*Architecture analysis: 2026-04-08*
