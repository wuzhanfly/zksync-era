# External Integrations

**Analysis Date:** 2026-04-08

## L1 Chain (Settlement Layer)

**BSC / Ethereum L1 RPC:**
- Role: Settlement layer for batch commitments, proof verification, bridge operations
- Client: `zksync_eth_client` (`core/lib/eth_client/`); trait `EthInterface` / `BoundEthInterface`
- Transport: `jsonrpsee` HTTP client via `DynClient<L1>` (`core/lib/web3_decl/`)
- Connection secret: `l1.l1_rpc_url` in `secrets.yaml` (env fallback: `ETH_CLIENT_URL`)
- This fork targets BSC (chain_id 56 mainnet / 97 testnet) as L1; Ethereum (1, 5, 11155111) also supported

**BSC-Specific Adaptations (all in `core/lib/eth_client/src/clients/http/query.rs`):**
- `detect_bsc_network_from_env()` reads `L1_CHAIN_ID` or `L1_RPC_URL` env vars to identify BSC
- `fee_history` API response padding: BSC returns truncated `base_fee_per_gas` arrays; code pads missing entries with last known value or 1 Gwei
- Blob fee data: BSC may return empty `base_fee_per_blob_gas`; padded with zeros (blob fees fetched from gas adjuster at send time)
- `oldest_block` mismatch: BSC does not strictly comply with Ethereum `fee_history` spec; mismatch is logged but not rejected for BSC

**Network-Aware Fee Oracle (`core/node/eth_sender/src/network_aware/`):**
- `detect_network_type(chain_id)` in `network_detector.rs` - maps chain_id to `NetworkType::{Ethereum, Bsc, Other}`
- `NetworkAwareFeesOracle` in `fees_oracle.rs` - dispatches to:
  - Ethereum: standard EIP-1559 fee path via `GasAdjusterFeesOracle`
  - BSC non-blob: legacy fee model with defaults 20 Gwei base / 1 Gwei priority; 100% price bump on retry; 10%/block time decay multiplier
  - BSC blob: delegates to standard EIP-1559 path (BEP-336 blob support)

**BSC Fee Optimization Config (`core/node/eth_sender/src/bsc_fee_config.rs`):**
- `BscFeeOptimizationConfig` loaded from env: `BSC_MIN_BASE_FEE`, `BSC_MAX_BASE_FEE`, `BSC_TARGET_BASE_FEE`, `BSC_FAST_PRIORITY_FEE`, `BSC_CONGESTION_THRESHOLD`, `BSC_FEE_OPTIMIZATION_ENABLED`
- Defaults: target 1 Gwei, max 5 Gwei, congestion threshold 3 Gwei

## Gas / Fee Estimation

**GasAdjuster (`core/node/fee_model/src/l1_gas_price/gas_adjuster/`):**
- Polls L1 via `EthFeeInterface::base_fee_history()` periodically
- Maintains rolling statistics for `base_fee`, `blob_base_fee`, `l2_pubdata_price`
- Exponential pricing formula: `fee = median * a * b^time_in_mempool`
- Config in `GasAdjusterConfig` (`core/lib/config/src/configs/eth_sender.rs`)
- Poll period, formula parameters `a`/`b`, max fee caps all configurable

**Pubdata Pricing Modes:**
- `Calldata`: fee = gas_price × L1_GAS_PER_PUBDATA_BYTE
- `Blobs`: fee uses `blob_base_fee_statistics.median()` + KZG predictor
- `Custom` (DA layers): returns 0 (external DA determines cost)
- `RelayedL2Calldata`: uses L2 pubdata price statistics

## Blob / EIP-4844 (BEP-336)

**Blob Transaction Support:**
- `EthTxBlobSidecar` enum (`core/lib/types/src/eth_sender.rs`): `EthTxBlobSidecarV1` (EIP-4844 with KZG proofs) and `EthTxBlobSidecarV2` (EIP-7594 / Fusaka cell proofs)
- `encode_blob_tx_with_sidecar()` in `core/lib/eth_client/src/types.rs` - RLP-encodes blob+commitment+proof per EIP-4844 networking spec
- `convert_eip4844_sidecar_to_eip7594_sidecar()` - conversion between formats (Fusaka disabled for BSC: no cell proof support)
- KZG library: `c-kzg = "2.1.1"`; internal KZG crate: `kzg = "=0.153.6"` (package `zksync_kzg`)
- BSC blob transactions use the EIP-1559 fee path in `NetworkAwareFeesOracle` (blob operator bypasses BSC legacy fee path)
- Note: Fusaka/EIP-7594 `use_fusaka_blob_format` must remain disabled for BSC (`fusaka_upgrade_block: Some(0)` or `fusaka_upgrade_timestamp: Some(...)` controls activation, set conservatively in test config)

**Blob Count per Protocol Version (`core/lib/types/src/blob.rs`):**
- pre-1.4.1: 0 blobs
- 1.4.1–1.5.0: 2 blobs
- ≥1.5.0: up to 16 supported, 6 created

## Data Availability (DA) Layers

**DA Client Interface:** `zksync_da_client` (`core/lib/da_client/`); implementations in `zksync_da_clients` (`core/node/da_clients/`)

**Avail:**
- Two modes: `FullClient` (direct WebSocket to Avail node) and `GasRelay` (via gas relay API)
- Config: `AvailConfig` with `bridge_api_url`, `api_node_url`, `app_id`
- Secret: `da.avail_api_key` in `secrets.yaml`
- Dependencies: `subxt-signer`, `parity-scale-codec`, `scale-encode`, `blake2b_simd`

**Celestia:**
- gRPC client to Celestia node using generated protobuf stubs (`core/node/da_clients/src/celestia/generated/`)
- Config: `CelestiaConfig` with node URL, namespace
- Secret: `da.celestia_private_key`
- Dependencies: `celestia-types`, `tonic`, `pbjson-types`

**EigenDA:**
- Uses `rust-eigenda-v2-client = "=0.1.4"` gRPC client
- Config: `EigenConfig` with `disperser_rpc`, `eigenda_eth_rpc`, `cert_verifier_router_addr`, `operator_state_retriever_addr`, `registry_coordinator_addr`, `blob_version`
- Secret: `da.eigenda_private_key`

**Object Store (default for local/testing):**
- File-backed, GCS, or S3 modes
- Config variant `DAClientConfig::ObjectStore(ObjectStoreConfig)`

**No DA:**
- `DAClientConfig::NoDA` - disables DA dispatch (used in Validium mode or testing)

**DA Dispatch:** `zksync_da_dispatcher` (`core/node/da_dispatcher/`) polls DB for batches needing DA submission, calls DA client, stores inclusion proof

## Object Store

**Purpose:** Stores prover artifacts (witness inputs, proofs), snapshots
**Modes** (`ObjectStoreMode` in `core/lib/config/src/configs/object_store.rs`):
- `GCS` / `GCSAnonymousReadOnly` / `GCSWithCredentialFile` - Google Cloud Storage
  - Auth: ambient credentials or `gcs_credential_file_path`
  - SDK: `google-cloud-storage = "0.20.0"` + `google-cloud-auth = "0.16.0"`
- `S3AnonymousReadOnly` / `S3WithCredentialFile` - AWS S3 / S3-compatible
  - SDK: `aws-sdk-s3 = "1.76.0"` + `aws-config = "1.1.7"`
  - Optional custom `endpoint` for non-AWS providers
- `FileBacked` - local filesystem (development/testing)
- Config key: `object_store` in `general.yaml`

## Databases

**PostgreSQL:**
- Primary data store for all node state, transactions, batches, proofs
- Client: `sqlx = "0.8.1"` async
- Connection pool: `ConnectionPool<Core>` in `core/lib/dal/`
- Config: `postgres.server_url` (secret) in `secrets.yaml`; fallback env `DATABASE_URL`
- Prover DB: separate `postgres.prover_url` (optional)
- Replica: `postgres.server_replica_url` (optional, read-only)
- DAL modules cover: blocks, transactions, ETH sender, ETH watcher, proofs, snapshots, DA, consensus, contract verification, pruning, VM runner, etc.

**RocksDB:**
- Embedded KV store for Merkle tree (`core/lib/merkle_tree/`)
- Also used by VM state storage
- Library: `rocksdb = "0.21"`
- Path configured via `db.merkle_tree.path` in `general.yaml`

## APIs Exposed

**JSON-RPC (Web3) (`core/node/api_server/src/web3/namespaces/`):**
- `eth_*` - Standard Ethereum namespace
- `net_*` - Network namespace
- `web3_*` - Web3 namespace
- `zks_*` - ZKsync-specific namespace (proof data, fee estimation, L1/L2 bridge queries)
- `debug_*` - Debug namespace (trace calls)
- `en_*` - External node sync namespace
- `snapshots_*` - Snapshot namespace
- Server: `jsonrpsee = "0.24"` with `axum` HTTP transport
- Port: configurable via `api.web3_json_rpc.http_port` / `ws_port`

**Health Check HTTP API:**
- `axum`-based server; port `api.healthcheck.port`
- Exposes `/health` with component statuses

**Merkle Tree API:**
- Port `api.merkle_tree.port`

**Prometheus Metrics:**
- `vise` + `vise-exporter` scrape endpoint
- Port `prometheus.listener_port`

**Proof Data Handler:**
- HTTP API for proof submission; `core/node/proof_data_handler/`
- External proof integration API: `core/node/external_proof_integration_api/`

## External Price APIs (Base Token Pricing)

**CoinGecko** (`core/lib/external_price_api/src/coingecko_api.rs`):
- Default URL: `https://pro-api.coingecko.com`
- Auth header: `x-cg-pro-api-key`
- Config: `external_price_api_client.source = "coingecko"`, `api_key`, `base_url`

**CoinMarketCap** (`core/lib/external_price_api/src/cmc_api.rs`):
- Default URL: `https://pro-api.coinmarketcap.com`
- Auth header: `x-cmc_pro_api_key`
- Config: `external_price_api_client.source = "coinmarketcap"`, `api_key`

**Forced Price Client** (`core/lib/external_price_api/src/forced_price_client.rs`):
- Returns a configured fixed ratio with optional fluctuation
- Used in testing or when price oracles are unavailable

**Used by:** `zksync_base_token_adjuster` (`core/node/base_token_adjuster/`) to adjust L2 base token ratio relative to ETH

## Contract Verification

**Etherscan Verification (`core/lib/contract_verifier/src/etherscan/`):**
- Calls Etherscan API to verify contracts on L1
- Secret: `contract_verifier.etherscan_api_key`

**GitHub Compiler Resolver (`core/lib/contract_verifier/src/resolver/github/`):**
- Downloads Solc / zkSolc / Vyper compilers from GitHub releases via `octocrab = "0.41"`

**Foundry Compilers:**
- `foundry-compilers` (forked via git from Moonsong-Labs) for local compilation

## Consensus

**BFT Consensus Network:**
- P2P gossip and consensus via `zksync_consensus_network = "=0.13"` + `zksync_consensus_bft = "=0.13"`
- Config: `consensus.yaml` with peer keys, boot nodes, validator set
- Secret: `consensus.validator_key`, `consensus.attester_key`
- Node: `zksync_node_consensus` (`core/node/consensus/`)

## Monitoring & Observability

**Sentry:**
- Error tracking via `sentry = "0.31"`
- Config: `observability.sentry.url` (env fallback: `MISC_SENTRY_URL`)
- Environment label: `$CHAIN_ETH_NETWORK - $CHAIN_ETH_ZKSYNC_NETWORK`

**OpenTelemetry:**
- Distributed traces exported via OTLP (`opentelemetry-otlp = "0.30.0"`)
- Config: `observability.opentelemetry.endpoint`
- Tracing bridge: `opentelemetry-appender-tracing`

**Structured Logging:**
- `tracing` + `tracing-subscriber`
- Format: `plain` or `json` (config: `observability.log_format`)
- Directives: `observability.log_directives` (env fallback: `RUST_LOG`)

## Environment Variables Summary

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL server URL fallback |
| `L1_CHAIN_ID` | BSC network detection (56=mainnet, 97=testnet) |
| `L1_RPC_URL` | BSC network detection fallback (URL heuristic) |
| `BSC_MIN_BASE_FEE` | BSC fee: minimum base fee in wei |
| `BSC_MAX_BASE_FEE` | BSC fee: maximum base fee in wei |
| `BSC_TARGET_BASE_FEE` | BSC fee: target base fee in wei |
| `BSC_FAST_PRIORITY_FEE` | BSC fee: fast priority fee in wei |
| `BSC_CONGESTION_THRESHOLD` | BSC fee: congestion detection threshold |
| `BSC_FEE_OPTIMIZATION_ENABLED` | BSC fee: enable/disable optimization |
| `MISC_SENTRY_URL` | Sentry DSN |
| `RUST_LOG` | Log directive fallback |
| `MISC_LOG_FORMAT` | Log format fallback |
| `ETH_SENDER_SENDER_OPERATOR_PRIVATE_KEY` | L1 operator private key (legacy fallback) |

---

*Integration audit: 2026-04-08*
