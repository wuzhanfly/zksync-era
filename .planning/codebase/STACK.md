# Technology Stack

**Analysis Date:** 2026-04-02

## Languages

**Primary:**
- Rust (nightly-2025-03-19) - Core blockchain infrastructure, node services, provers, CLI tools
- TypeScript/JavaScript - Frontend deployment scripts, Hardhat smart contract testing, tMai chain deployment

**Secondary:**
- Solidity - Smart contracts (L1 contracts, L2 contracts, DA contracts)
- Python - Testing and analysis utilities

## Runtime

**Environment:**
- Rust nightly toolchain: `nightly-2025-03-19` (specified in `/home/jerry/git/zksync-era/rust-toolchain`)
- Node.js: v18.20.8 (specified in `/home/jerry/git/zksync-era/.nvmrc`)

**Package Manager:**
- Cargo (Rust) - Primary dependency manager for core workspace
  - Lockfile: `core/Cargo.lock` present
  - Workspace structure: `/home/jerry/git/zksync-era/core/Cargo.toml` with ~90 workspace members
- npm/yarn (JavaScript) - For Hardhat, smart contract deployment, testing
  - Lockfile: `yarn.lock` and `package-lock.json` present

## Frameworks

**Core Blockchain:**
- Axum 0.8.4 - HTTP server framework for API endpoints and node services
- Tokio 1.x - Async runtime for concurrent task management
- Tower 0.4.13, tower-http 0.5.2 - HTTP middleware and utilities

**Smart Contracts & Testing:**
- Hardhat 2.28.4 - Solidity smart contract development and testing
- Foundry compilers (0.11.6) - Solidity compilation from custom fork
- ethers 6.11.0 (JavaScript), ethers 2.0 (Rust) - Ethereum library for contract interaction
- zksync-ethers 6.8.0 - ZKSync-specific Ethereum library extensions

**Consensus & Validation:**
- zksync_consensus_* (version 0.13) - Multiple consensus packages
  - zksync_consensus_bft, zksync_consensus_crypto, zksync_consensus_engine, zksync_consensus_executor, zksync_consensus_network, zksync_consensus_roles, zksync_consensus_utils

**Cryptography & Proving:**
- zksync_vm2 (0.5.0) - New virtual machine implementation
- zk_evm 0.131.0-0.153.6 - Multiple EVM versions for different VM states
- circuit_definitions, circuit_sequencer_api, circuit_encodings (0.153.6) - Circuit structures and definitions
- fflonk (0.32.7), bellman (0.32.7) - Proof systems
- boojum-cuda, fflonk-cuda (0.155.6) - GPU-accelerated proving
- c-kzg 2.1.1 - Cryptographic commitment scheme

**Build/Dev:**
- Cargo workspace (Rust monorepo)
- ts-node 10.9.2 - TypeScript execution for deployment scripts
- TypeScript 5.3.3 - Type safety for JavaScript/Node tooling

## Key Dependencies

**Critical Blockchain Infrastructure:**
- sqlx 0.8.1 - Database access with async/await (for PostgreSQL, prover DB)
- rocksdb 0.21 - Embedded key-value store for state/storage
- reqwest 0.12 - HTTP client for external API calls
- web3 0.19.0 - Legacy Ethereum web3 integration
- zksync_web3_decl - Custom web3 interface declarations

**Data Processing:**
- serde 1.0, serde_json 1.0, serde_yaml 0.9 - Serialization/deserialization
- prost 0.12.6 - Protocol buffers
- bincode 1.0 - Binary encoding
- RLP 0.5 - Ethereum RLP encoding

**Concurrency & Async:**
- tokio 1.x - Async runtime
- futures 0.3 - Async utilities
- async-trait 0.1 - Async trait support
- dashmap 5.5.3 - Concurrent hashmap
- rayon 1.3.1 - Data parallelism

**Storage & Caching:**
- mini-moka 0.10.0 - High-performance caching
- lru 0.16.3 - LRU cache
- tempfile 3.0.2 - Temporary file handling
- flate2 1.0.28 - Gzip compression

**Cloud & Infrastructure:**
- aws-sdk-s3 1.76.0 - AWS S3 object storage
- aws-config 1.1.7 - AWS configuration
- google-cloud-storage 0.20.0 - Google Cloud Storage
- google-cloud-auth 0.16.0 - Google Cloud authentication

**Observability & Monitoring:**
- tracing 0.1, tracing-subscriber 0.3 - Structured logging
- opentelemetry 0.30.0, opentelemetry-otlp 0.30.0 - OTEL metrics and traces
- opentelemetry-appender-tracing 0.30.0 - OTEL appender for logging
- sentry 0.31 - Error tracking integration
- vise 0.3.2, vise-exporter 0.3.2 - Custom metrics exporter

**Cryptography & Security:**
- secp256k1 0.27.0 - Elliptic curve signing
- sha2 0.10.8, sha3 0.10.8 - Hash functions
- blake2 0.10, blake2b_simd 1.0.2 - Blake2 hashing
- tiny-keccak 2.0 - Keccak hashing
- secrecy 0.10.3 - Secret value handling
- rustls 0.23 - TLS implementation

**Testing & Validation:**
- proptest 1.6.0 - Property-based testing
- insta 1.29.0 - Snapshot testing
- test-log 0.2.15, tracing-test 0.2.5 - Test logging

**CLI & Configuration:**
- clap 4.2.2 - Command-line argument parsing
- envy 0.4 - Environment variable configuration
- serde_yaml 0.9 - YAML configuration parsing
- smart-config 0.2.0-pre - Smart configuration loading

**DA (Data Availability) Client Dependencies:**
- celestia-types 0.6.1, tonic 0.11.0 - Celestia DA client
- rust-eigenda-v2-client, rust-eigenda-v2-common, rust-eigenda-signers - EigenDA integration
- base58 0.2.0, scale-encode 0.5.0, subxt-metadata 0.39.0, parity-scale-codec 3.6.9 - Avail DA support
- bech32 0.11.0, ripemd 0.1.3 - Address encoding for Celestia

## Configuration

**Environment:**
- Configuration loaded from environment variables via `envy` crate
- YAML-based configuration files parsed by `serde_yaml`
- Smart configuration with fallback values
- `.env` files present for local development (`.env.tmai`, `.env.example`)
- See `/home/jerry/git/zksync-era/core/lib/config/src/` for configuration module structure

**Build:**
- Cargo workspace configuration: `/home/jerry/git/zksync-era/core/Cargo.toml`
- Prover workspace: `/home/jerry/git/zksync-era/prover/Cargo.toml`
- ZKStack CLI workspace: `/home/jerry/git/zksync-era/zkstack_cli/Cargo.toml`
- Hardhat configuration: `/home/jerry/git/zksync-era/hardhat.config.js`
- Foundry configurations in contract directories

## Platform Requirements

**Development:**
- Rust nightly toolchain (nightly-2025-03-19)
- Node.js v18.20.8+
- PostgreSQL (required for state storage and prover DB)
- RocksDB (embedded, compiled as dependency)

**Production:**
- Docker containers (multiple Dockerfiles: `Dockerfile.server`, `Dockerfile.prebuilt`, `Dockerfile.tmai`, `docker/Dockerfile.optimized`)
- Kubernetes (k8s-openapi 0.24.0, kube 0.99.0 for cluster management)
- PostgreSQL database backend
- AWS S3 or Google Cloud Storage for object storage
- Ethereum L1 RPC endpoint for state commitments
- Data Availability client (Avail, Celestia, or EigenDA)

---

*Stack analysis: 2026-04-02*
