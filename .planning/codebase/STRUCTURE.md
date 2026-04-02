# Codebase Structure

**Analysis Date:** 2026-04-02

## Directory Layout

```
zksync-era/
├── core/                      # Main ZKsync node and server implementation (Rust)
├── prover/                    # ZKsync prover system (Rust)
├── zkstack_cli/               # ZKStack CLI tool for chain deployment (Rust)
├── contracts/                 # Smart contracts (Solidity) - Git submodule
├── docker/                    # Container definitions for all services
├── etc/                       # Configuration, bootloaders, test data
├── docs/                      # mdBook documentation
├── infrastructure/            # Deployment and upgrade testing infrastructure
├── external_node/             # External node components
├── private-rpc/               # Private RPC implementation
├── rpc-proxy/                 # RPC proxy service
├── stress-test/               # Load testing and stress test tools
├── test/                      # Integration and end-to-end tests
├── scripts/                   # Deployment and utility scripts
├── local/                     # Local development configuration
├── bin/                       # Utility binaries
├── .github/                   # GitHub workflows and CI/CD
├── .planning/                 # GSD planning documents
└── proof-manager-contracts/   # Proof manager smart contracts
```

## Directory Purposes

**`core/`** - Core ZKsync node implementation written in Rust
- Contains: Node binaries, libraries, and tests for the ZKsync Era blockchain
- Key files: `Cargo.toml` (workspace manifest), `CHANGELOG.md`
- Subdirectories:
  - `bin/`: Compiled binaries - `zksync_server`, `external_node`, `block_reverter`, `contract-verifier`, `genesis_generator`, etc.
  - `node/`: Node service implementations (API server, state keeper, consensus, eth_sender, etc.)
  - `lib/`: Shared libraries and core functionality

**`prover/`** - ZKsync proving system (generates validity proofs)
- Contains: Prover binaries, services, and utilities
- Key files: `Cargo.toml`, `Cargo.lock`, `CHANGELOG.md`
- Subdirectories:
  - `crates/bin/`: Prover binaries - `circuit_prover`, `witness_generator`, `prover_fri_gateway`, `proof_fri_compressor`, etc.
  - `crates/lib/`: Prover libraries - `prover_dal`, `prover_job_processor`, `circuit_prover_service`, etc.
  - `data/`: Prover test data and setup keys

**`zkstack_cli/`** - ZKStack CLI tool for deploying ZKsync chains
- Contains: CLI implementation in Rust
- Subdirectories:
  - `crates/zkstack/`: Main CLI implementation
  - `crates/common/`: Common utilities
  - `crates/config/`: Configuration handling
  - `crates/types/`: Type definitions

**`contracts/`** - All smart contracts (Git submodule)
- Contains: L1 and L2 smart contracts, bridge contracts, system contracts
- Subdirectories:
  - `l1-contracts/`: Layer 1 (Ethereum) contracts
  - `l2-contracts/`: Layer 2 (ZKsync) contracts
  - `system-contracts/`: Core system contracts, bootloader
  - `da-contracts/`: Data availability contracts
  - `gas-bound-caller/`: Gas bound related contracts

**`docker/`** - Docker container definitions
- Contains: Dockerfiles and build infrastructure
- Key subdirectories:
  - `build-base/`, `runtime-base/`: Base images
  - `circuit-prover-gpu/`, `proof-fri-gpu-compressor/`: GPU-accelerated services
  - `witness-generator/`, `prover-fri-gateway/`, `prover-job-monitor/`: Prover services
  - `contract-verifier/`: Contract verification service
  - `external-node/`: External node deployment
  - `snapshots-creator/`: Snapshot creation service

**`etc/`** - Configuration and static data
- Contains:
  - `env/`: Environment configurations for different networks
  - `multivm_bootloaders/`: VM bootloader implementations
  - `upgrades/`: Protocol upgrade data
  - `test_config/`: Test configuration templates
  - `tokens/`: Token information
  - `hyperchains/`: Hyperchain configurations

**`docs/`** - mdBook documentation
- Contains:
  - `src/`: Documentation sources (specs, guides)
  - `theme/`, `css/`, `js/`: Documentation styling

**`infrastructure/`** - Deployment and upgrade infrastructure
- Contains:
  - `protocol-upgrade/`: Protocol upgrade related code
  - `local-upgrade-testing/`: Local testing for upgrades

## Key File Locations

**Entry Points:**
- `core/bin/zksync_server/` - Main ZKsync server binary
- `core/bin/external_node/` - External node implementation
- `prover/crates/bin/circuit_prover/` - Circuit prover binary
- `zkstack_cli/crates/zkstack/` - ZKStack CLI binary

**Workspace Manifests:**
- `core/Cargo.toml` - Core workspace with ~50+ packages
- `prover/Cargo.toml` - Prover workspace with ~10+ packages
- `zkstack_cli/Cargo.toml` - CLI workspace with 4 packages

**Core Libraries (in `core/lib/`):**
- `basic_types/` - Fundamental blockchain types
- `config/` - Configuration management
- `constants/` - Protocol constants
- `dal/` - Database abstraction layer (with migrations)
- `storage/` - State storage interface
- `state/` - State management
- `types/` - Protocol types
- `vm_interface/` - Virtual machine interface
- `multivm/` - Multi-VM executor
- `merkle_tree/` - Merkle tree implementation
- `contract_verifier/` - Smart contract verification
- `eth_client/` - Ethereum RPC client
- `prover_interface/` - Prover communication interface
- `object_store/` - Object storage abstraction
- `node_framework/` - Node service framework

**Node Services (in `core/node/`):**
- `api_server/` - JSON-RPC API implementation
- `state_keeper/` - State persistence and block production
- `eth_sender/` - L1 batch submission
- `eth_watch/` - L1 event monitoring
- `consensus/` - Consensus mechanism
- `metadata_calculator/` - Block metadata computation
- `house_keeper/` - Maintenance tasks
- `db_pruner/` - Database pruning
- `node_sync/` - Node synchronization
- `commitment_generator/` - Commitment generation
- `da_dispatcher/` - Data availability coordination

**Prover Libraries (in `prover/crates/lib/`):**
- `prover_dal/` - Prover database access layer
- `circuit_prover_service/` - Circuit prover service
- `proof_fri_compressor_service/` - FRI compression service
- `witness_generator_service/` - Witness generation service
- `prover_job_processor/` - Job queue processing
- `keystore/` - Proof verification key storage

## Naming Conventions

**Directories:**
- Snake_case for Rust crate directories: `contract_verifier`, `node_storage_init`, `eth_sender`
- Hyphenated names for Docker/infra: `contract-verifier`, `zk-environment`

**Files:**
- Solidity contracts: PascalCase (e.g., `Bridgehub.sol`, `StateTransitionManager.sol`)
- Rust source: snake_case (e.g., `state_keeper.rs`, `eth_sender.rs`)
- Configuration: YAML or TOML (e.g., `foundry.toml`, `hardhat.config.ts`)
- Tests: `*.test.ts`, `*.spec.ts` for TypeScript; Rust tests inline with `#[cfg(test)]`

**Module Organization:**
- Cargo workspace members: `{name}/src/main.rs` or `{name}/src/lib.rs`
- Rust library crates: `src/mod.rs` with submodules

## Where to Add New Code

**New Blockchain Feature:**
- Implementation: `core/lib/{feature_name}/` (new library crate)
- Node service: `core/node/{service_name}/` if it requires a background service
- Configuration: `core/lib/config/`

**New Node Service:**
- Code: `core/node/{service_name}/src/`
- Must implement service trait from `node_framework`
- Wire in `core/bin/zksync_server/`

**New API Endpoint:**
- Implementation: `core/node/api_server/src/`
- Types: `core/lib/types/`

**New Smart Contract:**
- L1: `contracts/l1-contracts/contracts/{subdirectory}/`
- L2: `contracts/l2-contracts/contracts/{subdirectory}/`

**New Prover Component:**
- Binary: `prover/crates/bin/{binary_name}/`
- Library: `prover/crates/lib/{lib_name}/`
- Docker: `docker/{service_name}/Dockerfile`

**New CLI Command:**
- Implementation: `zkstack_cli/crates/zkstack/src/`
- Config types: `zkstack_cli/crates/config/src/`
