# Technology Stack

**Analysis Date:** 2026-04-08

## Languages

**Primary:**
- Rust (edition 2021) - All `core/` node services, libraries, and binaries
- SQL - Database migrations and queries via `sqlx` in `core/lib/dal/`

**Secondary:**
- TypeScript - Integration tests in `core/tests/ts-integration/`
- Solidity - Test/system contracts in `core/lib/test_contracts/` and `core/tests/ts-integration/contracts/`

## Runtime

**Environment:**
- Tokio async runtime (`tokio = "1"`) - used throughout all node services
- jemalloc allocator (`tikv-jemallocator = "0.5"`) - `core/node/jemalloc/` wired via `zksync_node_jemalloc` into main binaries

**Package Manager:**
- Cargo (Rust workspace)
- Lockfile: `core/Cargo.lock` present

## Workspace Version

- `29.7.1-non-semver-compat`
- Workspace root: `core/Cargo.toml`
- Workspace resolver: `"2"`

## Frameworks

**Node Service Framework:**
- `zksync_node_framework` (`core/lib/node_framework/`) - custom actor-based task/resource/wiring layer; tasks implement `Task`, builders implement `WiringLayer`, resources implement `Resource`
- `smart-config = "=0.2.0-pre"` - typed config deserialization from YAML/ENV; all config structs derive `DescribeConfig` + `DeserializeConfig`

**Web / RPC:**
- `axum = "0.8.4"` - HTTP API server for health checks, proof data handler, external APIs
- `jsonrpsee = "0.24"` - JSON-RPC server (Web3 namespaces: eth, net, web3, zks, debug, en); configured in `core/node/api_server/`
- `tower = "0.4.13"` + `tower-http = "0.5.2"` - middleware layers

**Async:**
- `tokio = "1"` with `sync`, `time`, `rt-multi-thread` features

**Testing:**
- Standard `cargo test` with `#[tokio::test]`
- `test-casing = "0.1.2"` for parametrized tests
- `insta = "1.29.0"` for snapshot testing
- `proptest = "1.6.0"` for property-based testing
- `httpmock = "0.7.0"` for mocking HTTP endpoints

**Build/Dev:**
- `prost = "0.12.6"` + `tonic = "0.11.0"` - gRPC/protobuf for Celestia DA client
- `foundry-compilers` (forked via git: Moonsong-Labs) - contract compilation for contract verifier

## Key Dependencies

**Blockchain / Crypto:**
- `web3 = "0.19.0"` - Ethereum RPC types and client primitives
- `ethabi = "18.0.0"` - ABI encoding/decoding
- `secp256k1 = "0.27.0"` - ECDSA signing
- `c-kzg = "2.1.1"` - KZG polynomial commitments for EIP-4844 blob proofs
- `tiny-keccak = "2"` - Keccak256/SHA3 hashing
- `rlp = "0.5"` - RLP encoding (used for blob transaction serialization)
- `zksync_vm2 = "=0.5.0"` - New zkEVM implementation
- `zk_evm_1_5_2 = "=0.153.6"` + earlier versions - historical zkEVM implementations (multivm)
- `circuit_encodings / circuit_sequencer_api / circuit_definitions = "=0.153.6"` - zkSNARK circuit interfaces
- `kzg = "=0.153.6"` (package: `zksync_kzg`) - KZG commitment library
- `fflonk = "=0.32.7"` + `bellman = "=0.32.7"` - proof system crates

**Consensus:**
- `zksync_concurrency / zksync_consensus_bft / zksync_consensus_crypto / zksync_consensus_network = "=0.13"` - BFT consensus stack

**Database:**
- `sqlx = "0.8.1"` - async PostgreSQL queries; DAL in `core/lib/dal/`
- `rocksdb = "0.21"` - embedded KV store for Merkle tree (`core/lib/merkle_tree/`)

**Storage:**
- `google-cloud-storage = "0.20.0"` + `google-cloud-auth = "0.16.0"` - GCS object store
- `aws-sdk-s3 = "1.76.0"` + `aws-config = "1.1.7"` - S3 object store

**Observability:**
- `tracing = "0.1"` + `tracing-subscriber = "0.3"` - structured logging
- `vise = "0.3.2"` + `vise-exporter = "0.3.2"` - Prometheus metrics framework
- `opentelemetry = "0.30.0"` + `opentelemetry-otlp = "0.30.0"` - distributed tracing
- `sentry = "0.31"` - error tracking

**Serialization:**
- `serde = "1"` + `serde_json = "1"` + `serde_yaml = "0.9"` - JSON/YAML
- `bincode = "1"` - binary serialization (blob sidecars in DB)
- `prost = "0.12.6"` - protobuf

**DA Layer Clients:**
- Avail: `base58`, `scale-encode`, `subxt-signer`, `parity-scale-codec`, `subxt-metadata`
- Celestia: `celestia-types = "0.6.1"`, `tonic`, `pbjson-types`, `bech32`, `ripemd`
- EigenDA: `rust-eigenda-v2-client = "=0.1.4"`, `rust-eigenda-v2-common = "=0.1.3"`, `rust-eigenda-signers`

**HTTP Client:**
- `reqwest = "0.12"` - used in price API clients, contract verifier, DA clients

**Rate Limiting:**
- `governor = "0.4.2"` - rate limiting for API servers

## Internal Crate Structure

**Binaries (`core/bin/`):**
- `zksync_server` - main sequencer/validator node
- `external_node` - external (follower) node
- `block_reverter` - emergency block reverter utility
- `contract-verifier` - standalone contract verification service
- `snapshots_creator` - snapshot generation tool
- `genesis_generator` - genesis state generator
- `zksync_tee_prover` - TEE-based prover

**Node Services (`core/node/`):**
- `eth_sender` - L1 transaction submission with BSC-aware fee oracle
- `eth_watch` - L1 event monitoring
- `fee_model` - L2 fee calculation with `GasAdjuster`
- `api_server` - JSON-RPC and REST API
- `state_keeper` - L2 block/batch production
- `commitment_generator` - L1 batch commitment data
- `da_dispatcher` - Data availability layer dispatch
- `da_clients` - Avail, Celestia, EigenDA, ObjectStore client implementations
- `metadata_calculator` - Merkle tree updates
- `consensus` - BFT consensus integration

**Libraries (`core/lib/`):**
- `eth_client` - L1 RPC client with BSC fee_history compatibility patches
- `dal` - Data access layer (PostgreSQL via sqlx)
- `types` - Core domain types (transactions, blocks, blobs, commitments)
- `config` - All configuration structs
- `multivm` - Multi-version zkEVM executor
- `node_framework` - Service/task/resource wiring framework
- `merkle_tree` - RocksDB-backed Merkle tree
- `external_price_api` - CoinGecko + CoinMarketCap price clients
- `web3_decl` - Web3 RPC declarations (jsonrpsee)

## Configuration

**Environment:**
- YAML files (`general.yaml`, `secrets.yaml`, `contracts.yaml`, `genesis.yaml`, `wallets.yaml`) loaded via `smart-config`
- `DATABASE_URL` env var fallback for Postgres connection
- `L1_RPC_URL` and `L1_CHAIN_ID` env vars used by BSC network detection in `core/lib/eth_client/src/clients/http/query.rs`
- BSC-specific env vars: `BSC_MIN_BASE_FEE`, `BSC_MAX_BASE_FEE`, `BSC_TARGET_BASE_FEE`, `BSC_FAST_PRIORITY_FEE`, `BSC_CONGESTION_THRESHOLD`, `BSC_FEE_OPTIMIZATION_ENABLED`

**Build:**
- `core/Cargo.toml` workspace with `[profile.perf]` for profiling builds
- `core/deny.toml` - cargo-deny configuration
- `.cargo/` config in `core/`

## Platform Requirements

**Development:**
- Rust stable (edition 2021)
- PostgreSQL (for DAL / sqlx)
- RocksDB system library (for Merkle tree)

**Production:**
- Linux x86_64 (jemalloc, rocksdb)
- PostgreSQL 14+
- Deployed as Docker containers; see `docker/server-v2/Dockerfile`

---

*Stack analysis: 2026-04-08*
