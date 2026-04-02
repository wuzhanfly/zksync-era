# Architecture

**Analysis Date:** 2026-04-02

## Pattern Overview

**Overall:** Plugin-based service composition using task and resource framework

**Key Characteristics:**
- Modular component architecture built on `ZkStackService` and `ZkStackServiceBuilder`
- Task-based execution model with resource dependency injection
- Pluggable layers (WiringLayers) for composing node functionality
- Clear separation between consensus/execution layer, synchronization, and API exposure
- Event-driven integration with L1 Ethereum network and external data availability providers

## Layers

**Data Access Layer (DAL):**
- Purpose: Unified database access to PostgreSQL with type-safe queries
- Location: `core/lib/dal/src/`
- Contains: Domain-specific DAL classes (BlocksDal, TransactionsDal, EthSenderDal, etc.)
- Depends on: `zksync_db_connection`, `sqlx`
- Used by: All components that need persistent storage

**VM Execution Layer:**
- Purpose: Execute transactions in multiple VM versions with state management
- Location: `core/lib/multivm/src/` and `core/lib/vm_executor/src/`
- Contains: `BatchExecutor` implementations for each protocol version
- Depends on: `zksync_types`, `zksync_state`, VM libraries (zk_evm_*)
- Used by: StateKeeper, VmRunner components

**State & Storage Layer:**
- Purpose: Manage blockchain state with RocksDB caching and storage reads
- Location: `core/lib/state/src/` and `core/lib/storage/src/`
- Contains: State readers, storage interfaces, snapshot management
- Depends on: `zksync_types`, RocksDB
- Used by: Executor, StateKeeper, metadata calculator

**Type System:**
- Purpose: Core domain types for transactions, blocks, operations
- Location: `core/lib/types/src/`
- Contains: `Transaction`, `L1Batch`, `L2Block`, protocol upgrades, fees
- Depends on: `zksync_basic_types`, crypto primitives
- Used by: All other layers

**Node Framework:**
- Purpose: Service composition, dependency injection, task lifecycle management
- Location: `core/lib/node_framework/src/`
- Contains: `Task` trait (with variants: Task, OneshotTask, Precondition, UnconstrainedTask), `Resource` trait, `WiringLayer` for component registration
- Depends on: `tokio`, `async-trait`
- Used by: All executable binaries (zksync_server, external_node)

**Configuration Layer:**
- Purpose: Unified configuration from environment variables and YAML files
- Location: `core/lib/config/src/`
- Contains: GeneralConfig, Secrets, Wallets, ContractsConfig, Genesis
- Depends on: `serde`, `envy`, `serde_yaml`
- Used by: Node builders during startup

**Observability Layer:**
- Purpose: Centralized logging, tracing, metrics, and error reporting
- Location: `core/lib/vlog/src/`
- Contains: Logging setup, OpenTelemetry integration, Sentry configuration
- Depends on: `tracing`, `opentelemetry`, `sentry`
- Used by: All components via `tracing` macros

**Ethereum Integration Layer:**
- Purpose: Interaction with L1 Ethereum chain and settlement layers
- Location: `core/lib/eth_client/src/` and `core/node/eth_watch/src/`
- Contains: Web3 client abstraction, event processing (priority ops, protocol upgrades, batch roots)
- Depends on: `web3`, `ethabi`
- Used by: EthWatch, EthSender, Proof Manager components

## Data Flow

**Transaction Ingestion:**

1. User submits transaction via API Server Web3 namespace
2. TxSender validates and accepts transaction to mempool
3. MempoolIO reads from mempool into StateKeeper
4. StateKeeper executes transaction in batch executor
5. StateKeeperIO persists L2 blocks and state updates to database

**Block Sealing and L1 Commitment:**

1. StateKeeper seals L2 block when seal criteria met (gas, time, transactions)
2. StateKeeperOutputHandler persists block to database
3. MetadataCalculator computes merkle proofs for state changes
4. CommitmentGenerator creates L1 batch commitments
5. EthSender batches commitments and publishes to L1 Ethereum
6. Proof handlers (EthProofManager, ProofDataHandler) manage proof generation and verification

**L1 Event Synchronization:**

1. EthWatch polls L1 Ethereum at configured intervals
2. Event processors decode smart contract events:
   - PriorityOpsEventProcessor: Processes priority operations from deposits
   - DecentralizedUpgradesEventProcessor: Tracks protocol upgrades
   - BatchRootProcessor: Processes settlement layer batch roots
3. Events persisted to database via EventsDal
4. EventsWeb3Dal provides read-only access to events for API responses

**Data Availability Flow:**

1. StateKeeper produces pubdata (state changes) after L2 block execution
2. DADispatcher selects DA client based on config (Avail, Celestia, EigenDA, ObjectStore, NoDA)
3. DA client submits pubdata to settlement layer
4. ProofDataHandler or TeeProofDataHandler retrieves DA data for proof generation

**State Management:**
- State snapshots stored in RocksDB with merkle tree commitments
- Tree updates via metadata calculator maintain state root history
- Snapshot recovery allows nodes to sync from recent snapshots instead of genesis
- Reorg detector monitors for L1 reorgs and triggers block reverter if needed

## Key Abstractions

**WiringLayer (Component Registration):**
- Purpose: Register task and resource dependencies into ZkStackService
- Examples: `StateKeeperLayer`, `EthWatchLayer`, `Web3ServerLayer`
- Pattern: Implement `WiringLayer` trait with method to add layer to service builder
- Located: Each component has `node/` subdirectory with layer implementation

**Task (Runnable Work):**
- Purpose: Unit of work that executes in the node lifecycle
- Variants:
  - `Task`: Runs until error or stop signal (main components)
  - `OneshotTask`: Runs and exits without stopping service
  - `Precondition`: Barrier task that checks invariants before main tasks start
  - `UnconstrainedTask`: Runs immediately without waiting for preconditions
- Pattern: Implement `Task` trait with `id()` method, optional `kind()` override, and `run()` async method

**Resource (Shared State/Interfaces):**
- Purpose: Shared dependencies injected into tasks
- Kinds:
  - `Plain`: No wrapper (requires Copy or similar)
  - `Shared`: Wrapped in `Arc<T>` for thread-safe sharing
  - `Boxed`: Wrapped in `Box<T>`
- Pattern: Implement `Resource<Kind>` trait with `name()` method
- Examples: `ConnectionPool`, `EthClient`, `ObjectStore`

**WiringLayer Pattern:**

```rust
pub struct MyComponentLayer;

impl WiringLayer for MyComponentLayer {
    fn layer_name(&self) -> &'static str {
        "my_component"
    }

    async fn wire(self, mut context: ServiceContext<'_>) -> Result<(), WiringError> {
        let config = context.config().some_config.clone();
        let pool = context.get_resource::<ConnectionPool<Core>>().await?;

        let component = MyComponent::new(config, pool);
        context.add_task(Box::new(MyTask::new(component)));
        context.add_resource(Arc::new(component) as Arc<dyn MyInterface>);

        Ok(())
    }
}
```

**StateKeeper (Core Block Producer):**
- Purpose: Main execution loop that seals L2 blocks and L1 batches
- Location: `core/node/state_keeper/src/keeper.rs`
- Pattern: Polls mempool for transactions, executes in VM, checks seal criteria
- Outputs: L2 blocks, L1 batches, execution metrics
- State variants: `BatchState::Uninit` → `BatchState::Init`

**EthWatch (L1 Event Listener):**
- Purpose: Polls L1 for smart contract events and processes them
- Location: `core/node/eth_watch/src/lib.rs`
- Pattern: Periodic polling with event processor chain
- Event processors implement `EventProcessor` trait for pluggable event handling
- Maintains state: last seen protocol version, next priority op ID, batch roots

**EthSender (L1 Transaction Publisher):**
- Purpose: Batches commitments/proofs and sends to L1 Ethereum
- Location: `core/node/eth_sender/src/`
- Components: `EthTxManager` (tracks tx lifecycle), `EthTxAggregator` (batches ops)
- Pattern: Observes commitments, aggregates, estimates gas, monitors confirmation

## Entry Points

**Main Server:**
- Location: `core/bin/zksync_server/src/main.rs`
- Triggers: `cargo run --bin zksync_server [--components api,tree,eth,state_keeper,...]`
- Responsibilities: Orchestrates main node with selectable components via CLI args
- Builder: `MainNodeBuilder` in `node_builder.rs` wires all layers

**External Node:**
- Location: `core/bin/external_node/src/main.rs`
- Triggers: `cargo run --bin external_node`
- Responsibilities: Runs read-only sync node, exposes API, supports consensus-based sync
- Builder: `ExternalNodeBuilder` wires subset of layers (no StateKeeper, no eth_sender)

**Utility Binaries:**
- `contract-verifier`: Verifies smart contract source code
- `genesis_generator`: Creates genesis block for new chains
- `block_reverter`: Reverts state to specific L1 batch
- `snapshots_creator`: Creates state snapshots for node recovery
- Located: `core/bin/{binary_name}/src/main.rs`

## Error Handling

**Strategy:** Result-based error propagation with context enrichment

**Patterns:**
- Use `anyhow::Result<T>` and `anyhow::Context` for error messages
- Each layer adds context with `.context("what was being done")?`
- Critical errors trigger task exit (DAL errors, execution failures)
- Recoverable errors trigger circuit breaker checks (eth_client timeouts, external API failures)

**Examples:**
- StateKeeper returns `OrStopped` wrapper for cancellation-aware operations
- EthWatch catches event processor errors and continues polling
- TxSender validates and rejects invalid transactions with detailed error messages

## Cross-Cutting Concerns

**Logging:** Via `tracing` crate with structured logging
- Pattern: `tracing::info!()`, `tracing::debug!()`, `tracing::warn!()`, `tracing::error!()`
- Observability setup in `vlog` layer initializes tracing subscribers
- Example: `tracing::info!("Sealed block {number} with {tx_count} transactions")`

**Validation:** Per-layer input validation with early rejection
- Transaction validation: `TxSender.proxy` checks signature, nonce, gas
- Execution validation: `StateKeeper.keeper` uses seal criteria to validate block state
- Event validation: `EventProcessor` implementations filter for valid events

**Authentication:** Whitelist-based access control for API endpoints
- Component: `DeploymentAllowListLayer` restricts contract deployment
- Optional whitelisted pool sink filters write operations
- Located: `core/node/api_server/src/node/`

---

*Architecture analysis: 2026-04-02*
