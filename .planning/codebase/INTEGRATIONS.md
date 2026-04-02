# External Integrations

**Analysis Date:** 2026-04-02

## APIs & External Services

**Price Feeds:**
- CoinGecko - Token price fetching for base token ratio calculations
  - SDK/Client: `reqwest` HTTP client
  - Config: `ExternalPriceApiClientConfig`
  - Code: `core/lib/external_price_api/src/coingecko_api.rs`
  - Auth: API key via `x-cg-pro-api-key` header (`EXTERNAL_PRICE_API_CLIENT_API_KEY`)
  - Default endpoint: `https://pro-api.coingecko.com`
  - Supports no-op forced price mode for testing

**Blockchain RPC:**
- Ethereum L1 RPC - Required for eth_sender, eth_watch, and proof management
  - SDK/Client: `web3` (v0.19.0) and `jsonrpsee` (v0.24)
  - Code: `core/lib/eth_client/`
  - Configuration: `EthConfig` in `core/lib/config/src/configs/eth_sender.rs`
  - Polling and transaction monitoring

**Smart Contract Verification:**
- Etherscan-compatible contract verification API
  - Code: `core/node/contract_verification_server/`
  - Configuration: `ContractVerifierConfig`

## Data Storage

**Databases:**

**PostgreSQL:**
- Primary database for all state, transactions, blocks, proofs, and metadata
- Connection: `sqlx` with native TLS support (v0.8.1)
- Code: `core/lib/db_connection/`
- Configuration: `PostgresConfig` in `core/lib/config/src/configs/database.rs`
- Required env vars: `DATABASE_URL` (main), `DATABASE_REPLICA_URL` (read-only)
- Connection pool: Configurable via `DATABASE_POOL_SIZE` (default 50)
- Statement timeout: Configurable via `statement_timeout_sec` (default 300s, replica only)
- Used by:
  - DAL (Data Access Layer) in `core/lib/dal/`
  - State keeper
  - API servers
  - Proof system

**RocksDB:**
- Local embedded key-value store for VM state cache and Merkle tree
- Client: `rocksdb` crate (v0.21)
- Paths configured in `DBConfig`:
  - State keeper DB: `./db/main/state_keeper` (via `state_keeper_db_path`)
  - Merkle tree: `./db/main/tree` (via `merkle_tree.path`)
  - Merkle tree backups: `./db/main/backups` (via `merkle_tree.backup_path`)
- Used by:
  - State keeper for transaction execution cache
  - Merkle tree for state commitments
  - Snapshots applier

## File Storage

**Object Store (Abstraction):**
- Abstract storage backend for proofs, artifacts, witness data, and snapshots
- Code: `core/lib/object_store/`
- Configuration: `ObjectStoreConfig` in `core/lib/config/src/configs/object_store.rs`
- Features: Retries (configurable, default 5), local mirroring
- Code paths: `core/lib/object_store/src/{factory.rs, s3.rs, gcs.rs, file.rs}`

**AWS S3:**
- S3-compatible object storage for proofs and artifacts
- SDK/Client: `aws-sdk-s3` (v1.76.0), `aws-config` (v1.1.7)
- Code: `core/lib/object_store/src/s3.rs`
- Auth modes:
  - Credential file authentication: `S3WithCredentialFile` (path in `s3_credential_file_path`)
  - Anonymous read-only: `S3AnonymousReadOnly`
- Configuration:
  - Bucket URL: `OBJECT_STORE_BUCKET_BASE_URL` or mode-specific env vars
  - Endpoint override: `OBJECT_STORE_*_ENDPOINT` (for S3-compatible providers)
  - Region: `OBJECT_STORE_*_REGION` (inferred from AWS env by default)
  - Max retries: `OBJECT_STORE_MAX_RETRIES` (default 5)

**Google Cloud Storage (GCS):**
- GCS-based object storage for proofs and artifacts
- SDK/Client: `google-cloud-storage` (v0.20.0), `google-cloud-auth` (v0.16.0)
- Code: `core/lib/object_store/src/gcs.rs`
- Auth modes:
  - Ambient authentication (default GCP credentials)
  - Credential file: `GCSWithCredentialFile` (path in `gcs_credential_file_path`)
  - Anonymous read-only: `GCSAnonymousReadOnly`

**Local File Storage:**
- Fallback file-backed storage for development and testing
- Mode: `ObjectStoreMode::FileBacked`
- Base path: `OBJECT_STORE_FILE_BACKED_BASE_PATH` (default `./artifacts`)

**Local Mirroring:**
- Optional local filesystem caching of remote object store objects
- Configuration: `OBJECT_STORE_LOCAL_MIRROR_PATH`

## Authentication & Identity

**Ethereum Signing:**
- Private key management for L1 transaction signing
- Code: `core/lib/eth_signer/`
- Used by: `eth_sender` for sending transactions to L1
- Key source: `PRIVATE_KEY` or derived from seed phrase

## Monitoring & Observability

**Sentry:**
- Error and issue tracking integration
- SDK: `sentry` (v0.31)
- Code: `core/lib/vlog/src/sentry.rs`
- Configuration: `SentryConfig` in `core/lib/config/src/configs/observability.rs`
- Environment vars:
  - URL: `MISC_SENTRY_URL` (default "unset" - disables integration)
  - Environment: Auto-derived from `CHAIN_ETH_NETWORK` and `CHAIN_ETH_ZKSYNC_NETWORK`

**Logging:**
- Structured logging via `tracing` crate
- Code: `core/lib/vlog/` (observability stack)
- Format: Configurable via `MISC_LOG_FORMAT` (plain or json)
- Directives: `RUST_LOG` environment variable (default `zksync=info`)

**OpenTelemetry:**
- Distributed tracing and observability
- SDKs: `opentelemetry` (v0.30.0), `opentelemetry_sdk`, `opentelemetry-otlp` (with http-proto)
- Code: `core/lib/vlog/src/opentelemetry/mod.rs`
- Configuration: `OpentelemetryConfig` in `core/lib/config/src/configs/observability.rs`
- Environment vars:
  - Traces endpoint: `OTLP_ENDPOINT` (required if OpenTelemetry enabled)
  - Logs endpoint: `OTLP_LOGS_ENDPOINT` (optional)
  - Log level: `OPENTELEMETRY_LEVEL` (default "info")

**Prometheus/Vise:**
- Metrics collection and export
- Libraries: `vise` (v0.3.2), `vise-exporter` (v0.3.2)
- Code: `core/node/shared_metrics/`
- Configuration: `PrometheusConfig` in `core/lib/config/src/configs/general.rs`

## Data Availability Layer Integrations

**DA Client Architecture:**
- Abstract trait-based system in `core/lib/da_client/`
- Implementations via `core/node/da_clients/`
- Configuration: `DAClientConfig` (tagged enum) in `core/lib/config/src/configs/da_client/mod.rs`
- Supports pluggable DA providers with fallback to object store

**Avail:**
- Blockchain-based DA service for posting transaction data
- Client: `subxt` (v0.39.0) - Substrate/Polkadot client
- Configuration: `AvailConfig` in `core/lib/config/src/configs/da_client/avail.rs`
- Client types:
  - **FullClient**: Direct Avail node connection (WebSocket)
  - **GasRelay**: Relay service for gasless submissions
- Code: `core/node/da_clients/src/avail/`

**Celestia:**
- Modular blockchain DA layer
- Client: gRPC with protobuf support
- SDKs: `celestia-types` (v0.6.1), `tonic` (v0.11.0)
- Configuration: `CelestiaConfig` in `core/lib/config/src/configs/da_client/celestia.rs`
- Code: `core/node/da_clients/src/celestia/`

**EigenDA:**
- Eigenlayer-based DA service using EigenDA V2
- Client: Rust EigenDA SDK
- SDKs: `rust-eigenda-v2-client` (v0.1.4)
- Configuration: `EigenConfig` in `core/lib/config/src/configs/da_client/eigen.rs`
- Code: `core/node/da_clients/src/eigen/`

**NoDA:**
- No data availability (for testing/development)
- Configuration: `DAClientConfig::NoDA`

## Webhooks & Callbacks

**Outgoing:**
- Data Availability layer dispatching via `da_dispatcher` to DA services
  - Code: `core/node/da_dispatcher/`
  - Configuration: `DADispatcherConfig`

## Environment Configuration

**Required Core Environment Variables:**

**Database:**
- `DATABASE_URL` - PostgreSQL main connection string
- `DATABASE_REPLICA_URL` - PostgreSQL read-only replica (optional)
- `DATABASE_POOL_SIZE` - Connection pool size (default 50)

**Ethereum L1:**
- L1 RPC endpoint - Via `EthConfig`
- L1 network: `CHAIN_ETH_NETWORK`
- L2 network: `CHAIN_ETH_ZKSYNC_NETWORK`

**Object Store:**
- Mode: `OBJECT_STORE_MODE` (S3AnonymousReadOnly, GCS, GCSWithCredentialFile, FileBacked)
- Bucket: `OBJECT_STORE_BUCKET_BASE_URL`
- Retries: `OBJECT_STORE_MAX_RETRIES` (default 5)

**Price API:**
- Source: `EXTERNAL_PRICE_API_CLIENT_SOURCE` (coingecko, no-op, etc.)
- API Key: `EXTERNAL_PRICE_API_CLIENT_API_KEY` (optional)

**Observability:**
- Sentry URL: `MISC_SENTRY_URL` (default "unset")
- OTLP Endpoint: `OTLP_ENDPOINT` (for distributed tracing)
- Log format: `MISC_LOG_FORMAT` (plain or json)
- Log directives: `RUST_LOG`

## Configuration Sources & Hierarchy

**Configuration System:**
- Framework: `smart_config` (v0.2.0-pre)
- Code: `core/lib/config/`
- Sources (in order of precedence):
  1. Environment variables
  2. YAML/TOML configuration files
  3. Fallback defaults
  4. Manual configuration sources
