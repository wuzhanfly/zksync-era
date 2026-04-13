# Codebase Structure

**Analysis Date:** 2026-04-08

## Directory Layout

```
core/
├── bin/                          # Executable crates (entry points)
│   ├── zksync_server/            # Main node binary
│   ├── external_node/            # External/replica node binary
│   ├── block_reverter/           # Reorg recovery tool
│   ├── contract-verifier/        # Contract verification service binary
│   ├── custom_genesis_export/    # Genesis state export tool
│   ├── genesis_generator/        # First-time genesis initialization
│   ├── merkle_tree_consistency_checker/
│   ├── selector_generator/       # ABI selector generation utility
│   ├── snapshots_creator/        # Snapshot export tool
│   ├── system-constants-generator/
│   ├── verified_sources_fetcher/
│   └── zksync_tee_prover/        # TEE-based prover binary
│
├── node/                         # Node-integrated component crates
│   ├── api_server/               # JSON-RPC server (eth_/zks_/debug_ namespaces)
│   ├── base_token_adjuster/      # Non-ETH base token price feed
│   ├── block_reverter/           # Block reversion library
│   ├── commitment_generator/     # L1 batch commitment computation
│   ├── consensus/                # BFT consensus (main node & external node modes)
│   ├── consistency_checker/      # Validates L1 vs DB state agreement
│   ├── contract_verification_server/ # Solidity/Vyper verification HTTP server
│   ├── da_clients/               # DA provider implementations (Avail, Celestia, EigenDA)
│   ├── da_dispatcher/            # Sends pubdata to configured DA layer
│   ├── db_pruner/                # Prunes old data from PostgreSQL
│   ├── eth_proof_manager/        # Manages proof submission/verification on L1
│   ├── eth_sender/               # Aggregates and sends L1 commit/prove/execute txs
│   ├── eth_watch/                # Polls L1 (BSC) for priority ops and upgrades
│   ├── external_proof_integration_api/ # HTTP API for external provers
│   ├── fee_model/                # L1 gas price tracking and batch fee computation
│   ├── gateway_migrator/         # Settlement layer migration tooling
│   ├── genesis/                  # Genesis block initialization
│   ├── house_keeper/             # Periodic DB maintenance / prover job scheduling
│   ├── jemalloc/                 # Jemalloc allocator wiring
│   ├── logs_bloom_backfill/      # Backfill logs bloom filter in DB
│   ├── metadata_calculator/      # Builds and maintains the Merkle state tree
│   ├── node_storage_init/        # Storage initialization (main node & external node)
│   ├── node_sync/                # External node sync from main node JSON-RPC
│   ├── proof_data_handler/       # HTTP handler for prover job data
│   ├── reorg_detector/           # Detects and triggers L1 reorg handling
│   ├── shared_metrics/           # Prometheus metrics shared across components
│   ├── state_keeper/             # Core L2 block/batch sequencer and executor
│   ├── tee_proof_data_handler/   # TEE prover job data handler
│   ├── test_utils/               # Shared test helpers for node/ crates
│   ├── vm_runner/                # Framework for re-executing batches outside state_keeper
│   └── zk_os_tree_manager/       # ZK OS (EVM-compatible) tree manager
│
├── lib/                          # Pure library crates (no node-framework dependency)
│   ├── basic_types/              # Primitive types: H256, U256, Address, L1/L2ChainId
│   ├── circuit_breaker/          # Safety halt on detected inconsistencies
│   ├── config/                   # All configuration structs (smart_config-based)
│   ├── constants/                # Protocol constants (gas, fees, system addresses)
│   ├── contracts/                # ABI definitions for ZKsync L1/L2 contracts
│   ├── contract_verifier/        # Verification logic (compilers, Etherscan)
│   ├── crypto_primitives/        # EIP-712, hasher implementations
│   ├── da_client/                # DA client trait definition
│   ├── dal/                      # Data access layer: all PostgreSQL interactions
│   ├── db_connection/            # ConnectionPool, Connection, sqlx wrapper
│   ├── eth_client/               # L1 (BSC) RPC client traits and HTTP implementation
│   ├── eth_signer/               # Transaction signing (private key, hardware)
│   ├── external_price_api/       # External price feed client
│   ├── health_check/             # ReactiveHealthCheck, HealthUpdater
│   ├── instrument/               # Allocation instrumentation
│   ├── l1_contract_interface/    # ABI encoding for IExecutor.sol (commit/prove/execute)
│   ├── mempool/                  # In-memory mempool store
│   ├── merkle_tree/              # Sparse Merkle tree (original implementation)
│   ├── mini_merkle_tree/         # Small in-memory Merkle tree utility
│   ├── multivm/                  # Multi-version VM abstraction (vm_m5 through vm_latest)
│   ├── node_framework/           # WiringLayer/Task/Resource/ZkStackService framework
│   ├── node_framework_derive/    # Derive macros: FromContext, IntoContext
│   ├── object_store/             # Blob storage abstraction (GCS, S3, local)
│   ├── prover_interface/         # Shared types between node and prover
│   ├── queued_job_processor/     # Generic async job queue processor
│   ├── settlement_layer_data/    # Settlement layer type definitions
│   ├── shared_resources/         # Shared resource trait definitions (SyncState, TreeApiClient)
│   ├── snapshots_applier/        # Apply DB snapshots for fast sync
│   ├── state/                    # ReadStorage, WriteStorage traits + implementations
│   ├── storage/                  # RocksDB wrapper
│   ├── task_management/          # Async task lifecycle utilities
│   ├── tee_prover_interface/     # TEE prover shared types
│   ├── tee_verifier/             # TEE attestation verification
│   ├── test_contracts/           # Compiled test contract bytecodes
│   ├── types/                    # Core domain types (Transaction, L1Batch, Block, etc.)
│   ├── utils/                    # General utility functions
│   ├── vlog/                     # Logging/observability initialization
│   ├── vm_executor/              # VM batch execution (storage, whitelist, etc.)
│   ├── vm_interface/             # BatchExecutor, Halt, L1BatchEnv traits
│   ├── web3_decl/                # JSON-RPC namespace trait declarations
│   └── zk_os_merkle_tree/        # ZK OS Merkle tree implementation
│
└── tests/                        # Integration and load tests
    ├── gateway-migration-test/   # Settlement layer migration integration test
    ├── highlevel-test-tools/     # High-level test helpers
    ├── loadnext/                 # Load testing tool
    ├── recovery-test/            # Snapshot recovery integration test
    ├── ts-integration/           # TypeScript end-to-end tests (jest, ethers.js)
    ├── upgrade-test/             # Protocol upgrade integration test
    └── vm-benchmark/             # VM execution benchmarks
```

## Directory Purposes

**`core/bin/`:**
- Purpose: Thin executable wrappers. Each contains only `main.rs` and optionally `node_builder.rs` / `components.rs`
- Key files: `core/bin/zksync_server/src/main.rs`, `core/bin/external_node/src/main.rs`

**`core/node/`:**
- Purpose: Self-contained component crates. Each owns its business logic + a `pub mod node` that exposes a `WiringLayer` for registering with the service framework
- Pattern: Every crate in `core/node/` that runs as a long-lived task has `src/node/mod.rs` or `src/node.rs`

**`core/lib/`:**
- Purpose: Framework-independent libraries. May be used by provers, external tools, and tests without pulling in node wiring code
- Key distinction: These crates do NOT depend on `core/lib/node_framework`

**`core/tests/`:**
- Purpose: Integration tests that require a running stack. Not unit tests.
- Key files: `core/tests/ts-integration/tests/` for end-to-end JSON-RPC coverage

## Key File Locations

**Entry Points:**
- `core/bin/zksync_server/src/main.rs`: Main node startup, config loading, node assembly
- `core/bin/external_node/src/main.rs`: External node startup
- `core/bin/zksync_server/src/node_builder.rs`: `MainNodeBuilder` — wires all components

**Configuration:**
- `core/lib/config/src/configs/general.rs`: `GeneralConfig` — root config struct
- `core/lib/config/src/configs/eth_sender.rs`: `EthConfig`, `SenderConfig`, `GasAdjusterConfig`
- `core/lib/config/src/configs/genesis.rs`: `GenesisConfig`
- `core/lib/config/src/configs/secrets.rs`: `Secrets` — private keys, DB URLs

**Core Domain Types:**
- `core/lib/types/src/lib.rs`: Re-exports all primitive types
- `core/lib/types/src/commitment.rs`: `L1BatchCommitment`, `L1BatchWithMetadata`
- `core/lib/types/src/eth_sender.rs`: `EthTx`, `EthTxBlobSidecar`
- `core/lib/types/src/block.rs`: `L2BlockExecutionData`, `L1BatchHeader`

**Database Access:**
- `core/lib/dal/src/lib.rs`: DAL entry point, lists all ~30 sub-DALs
- `core/lib/dal/src/blocks_dal.rs`: L1 batch and L2 block DB operations
- `core/lib/dal/src/transactions_dal.rs`: Transaction DB operations
- `core/lib/dal/src/eth_sender_dal.rs`: L1 tx queue and history
- `core/lib/dal/migrations/`: All SQL migrations (numbered sequentially)

**State Keeper (sequencer):**
- `core/node/state_keeper/src/keeper.rs`: `StateKeeper` main loop
- `core/node/state_keeper/src/io/mempool.rs`: `MempoolIO` — main node tx source
- `core/node/state_keeper/src/seal_criteria/`: Batch sealing decision logic
- `core/node/state_keeper/src/executor/`: `BatchExecutor` wrapper

**L1 Interaction:**
- `core/node/eth_sender/src/eth_tx_aggregator.rs`: Groups batches into L1 ops, encodes ABI
- `core/node/eth_sender/src/eth_tx_manager.rs`: Sends and tracks L1 txs
- `core/node/eth_sender/src/eth_fees_oracle.rs`: Fee calculation; contains `BscGasPriceProvider`
- `core/node/eth_sender/src/network_aware/network_detector.rs`: BSC vs Ethereum detection
- `core/node/eth_watch/src/lib.rs`: BSC event polling (5000-block range limit at line 218)
- `core/lib/eth_client/src/clients/http/`: HTTP JSON-RPC client for L1/L2
- `core/lib/l1_contract_interface/src/i_executor/`: Calldata encoding for commit/prove/execute

**Merkle Tree:**
- `core/node/metadata_calculator/src/lib.rs`: `MetadataCalculator` — drives tree updates
- `core/node/metadata_calculator/src/updater.rs`: `TreeUpdater` — batch processing loop
- `core/lib/zk_os_merkle_tree/src/`: ZK OS sparse Merkle tree implementation
- `core/lib/storage/src/`: RocksDB backend for the tree

**VM Execution:**
- `core/lib/multivm/src/lib.rs`: Multi-version VM dispatcher
- `core/lib/multivm/src/versions/`: One submodule per protocol version (`vm_latest`, `vm_1_4_2`, etc.)
- `core/lib/vm_executor/src/`: Production `BatchExecutorFactory` implementation

**BSC-Specific Code:**
- `core/node/eth_sender/src/network_aware/network_detector.rs`: `NetworkType` enum, chain ID routing
- `core/node/eth_sender/src/eth_fees_oracle.rs`: `BscGasPriceProvider`, legacy tx mode
- `core/node/eth_watch/src/lib.rs`: 5000-block range cap for BSC `eth_getLogs`
- `core/lib/eth_client/src/clients/http/`: `fee_history` padding for BSC incomplete responses

**Testing:**
- `core/node/*/src/testonly/`: Test helpers and mock implementations per component
- `core/node/test_utils/src/`: Cross-component test utilities
- `core/tests/ts-integration/tests/`: Jest test suites organized by feature

## Naming Conventions

**Files:**
- Snake_case for all Rust source files: `eth_tx_manager.rs`, `metadata_calculator.rs`
- Test files co-located: `src/tests/` subdirectory or `src/tests.rs` inside the crate
- Node wiring: always at `src/node/mod.rs` or `src/node.rs`

**Directories:**
- Crate names use underscores (`state_keeper`, `eth_sender`, `da_dispatcher`)
- Exception: `contract-verifier` uses hyphens in directory name (maps to crate name with underscores)

**Rust Identifiers:**
- Structs: `PascalCase` — `StateKeeper`, `EthTxManager`, `MetadataCalculator`
- Traits: `PascalCase` — `StateKeeperIO`, `BatchExecutor`, `EthClient`
- Modules: `snake_case`
- Constants: `SCREAMING_SNAKE_CASE`
- Config structs follow the pattern: `{Component}Config` — `SenderConfig`, `GasAdjusterConfig`

## Where to Add New Code

**New node component (long-running task):**
- Create crate under `core/node/my_component/`
- Business logic in `src/lib.rs` or `src/my_component.rs`
- Node wiring in `src/node/mod.rs` implementing `WiringLayer`
- Register the layer in `core/bin/zksync_server/src/node_builder.rs`

**New library (shared logic, no node-framework dependency):**
- Create crate under `core/lib/my_lib/`
- Add to `core/Cargo.toml` workspace members

**New DAL method:**
- Add to the appropriate sub-DAL in `core/lib/dal/src/`
- If new table, add SQL migration to `core/lib/dal/migrations/`

**New L1 contract method call:**
- Add encoding in `core/lib/l1_contract_interface/src/i_executor/methods/`
- Add ABI definition in `core/lib/contracts/src/`

**New configuration option:**
- Add field to relevant struct in `core/lib/config/src/configs/`
- Use `smart_config` derive macros (`DescribeConfig`, `DeserializeConfig`)
- New env var follows pattern: `ZKSYNC_{SECTION}_{FIELD}`

**New DA backend:**
- Implement `DataAvailabilityClient` from `core/lib/da_client/src/`
- Add implementation under `core/node/da_clients/src/my_backend/`
- Wire in `core/node/da_clients/src/node/`

**Tests for a node/ component:**
- Unit/integration tests: `core/node/my_component/src/tests/`
- Cross-stack tests: `core/tests/ts-integration/tests/`

## Special Directories

**`core/lib/dal/migrations/`:**
- Purpose: Ordered SQL migration files applied by `sqlx migrate run`
- Generated: No (hand-written)
- Committed: Yes

**`core/lib/dal/.sqlx/`:**
- Purpose: Cached sqlx query metadata for compile-time checked queries
- Generated: Yes (`cargo sqlx prepare`)
- Committed: Yes (enables offline compilation)

**`core/target/`:**
- Purpose: Cargo build output
- Generated: Yes
- Committed: No (excluded via `.gitignore`)

**`core/node/da_clients/src/*/generated/`:**
- Purpose: Protobuf-generated Rust code (e.g., Celestia gRPC)
- Generated: Yes (build.rs)
- Committed: Yes

---

*Structure analysis: 2026-04-08*
