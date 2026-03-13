# Codebase Structure

**Analysis Date:** 2026-03-13

## Directory Layout

```
/home/jerry/git/zksync-era/FlashMallRelayer/
├── cmd/                    # Entry points
├── configs/                # Configuration files
├── contracts/              # Solidity contracts
├── docker/                 # Docker build files
├── internal/               # Private application code
│   ├── cluster/           # Raft consensus
│   ├── common/            # Shared types and utilities
│   ├── config/            # Configuration loading
│   ├── fault/             # Fault detection
│   ├── l1/                # L1 blockchain client
│   ├── l2/                # L2 blockchain client
│   ├── monitoring/        # Metrics and alerting
│   ├── relayer/           # Trade processing logic
│   ├── server/            # HTTP API server
│   ├── storage/           # Redis and Postgres clients
│   └── sync/              # Merkle synchronization
├── k8s/                   # Kubernetes manifests
├── pkg/                   # Public packages
├── scripts/               # Operational scripts
└── Makefile              # Build automation
```

## Directory Purposes

**`cmd/relayer/`:**
- Purpose: Application entry point
- Contains: `main.go` - bootstraps all services

**`internal/`:**
- Purpose: Private application code (not importable by external packages)
- Contains: All business logic

**`internal/server/`:**
- Purpose: HTTP API server
- Contains: `http.go` (Gin server, routes, handlers), `middleware.go` (auth, rate limiting)
- Key files: `internal/server/http.go`

**`internal/relayer/`:**
- Purpose: Core trade processing
- Contains: `trade_handler.go` (workers, queue, event listening), `retry.go`
- Key files: `internal/relayer/trade_handler.go`

**`internal/l1/`:**
- Purpose: L1 Ethereum interaction
- Contains: `client.go` (RPC, contracts, signing)
- Key files: `internal/l1/client.go`

**`internal/l2/`:**
- Purpose: L2 zkSync interaction
- Contains: `client.go` (RPC, event parsing, Merkle proofs)
- Key files: `internal/l2/client.go`

**`internal/storage/`:**
- Purpose: Data persistence
- Contains: `redis.go` (Redis client), `postgres.go`
- Key files: `internal/storage/redis.go`

**`internal/cluster/`:**
- Purpose: Distributed consensus
- Contains: `raft.go` (HashiCorp Raft implementation)
- Key files: `internal/cluster/raft.go`

**`internal/sync/`:**
- Purpose: L2-to-L1 synchronization
- Contains: `merkle_syncer.go` (block sync)
- Key files: `internal/sync/merkle_syncer.go`

**`internal/common/`:**
- Purpose: Shared types and utilities
- Contains: `types.go` (Trade, TradeEvent, TradeStatus), `validation.go`, `errors.go`, `utils.go`
- Key files: `internal/common/types.go`

**`internal/config/`:**
- Purpose: Configuration management
- Contains: `config.go` (Viper config loading)
- Key files: `internal/config/config.go`

**`internal/monitoring/`:**
- Purpose: Observability
- Contains: `metrics.go`, `alerter.go`
- Key files: `internal/monitoring/metrics.go`

**`pkg/merkle/`:**
- Purpose: Merkle tree implementation
- Contains: `tree.go`
- Key files: `pkg/merkle/tree.go`

**`configs/`:**
- Purpose: Configuration files
- Contains: YAML config templates

## Key File Locations

**Entry Points:**
- `cmd/relayer/main.go`: Application bootstrap

**Configuration:**
- `internal/config/config.go`: Viper-based YAML config
- `configs/`: YAML config files

**Core Logic:**
- `internal/relayer/trade_handler.go`: Trade processing
- `internal/l1/client.go`: L1 interactions
- `internal/l2/client.go`: L2 interactions

**Storage:**
- `internal/storage/redis.go`: Redis operations

**Cluster:**
- `internal/cluster/raft.go`: Raft consensus

## Naming Conventions

**Files:**
- Single file per package with matching name: `client.go`, `raft.go`
- Multi-word: lowercase with underscores: `trade_handler.go`, `merkle_syncer.go`

**Directories:**
- Single word or compound: `cluster/`, `monitoring/`, `relayer/`
- All lowercase

**Go Packages:**
- Single word: `relayer`, `cluster`, `sync`
- Matches directory name

**Types:**
- PascalCase: `TradeHandler`, `MerkleSyncer`, `Redis`
- Exported types in `common/`: `Trade`, `TradeEvent`, `TradeStatus`

**Functions:**
- PascalCase (exported): `NewClient`, `NewServer`, `Start`
- camelCase (unexported): `listenL2Events`, `processTrade`

**Variables:**
- camelCase: `l2Client`, `raftNode`, `tradeQueue`
- Acronyms: `RPCURL`, `WSURL` (initial caps)

## Where to Add New Code

**New Feature:**
- Primary code: `internal/{feature}/`
- Tests: `internal/{feature}/` or `internal/{feature}_test.go`

**New Handler Endpoint:**
- Implementation: `internal/server/http.go` - add route in `setupRoutes()`, add handler method

**New Trade Processing Step:**
- Implementation: `internal/relayer/trade_handler.go` - add to `processTrade()`

**New Blockchain Interaction:**
- Implementation: `internal/l1/` or `internal/l2/` - add client method

**New Redis Operation:**
- Implementation: `internal/storage/redis.go` - add method to Redis struct

**New Metric:**
- Implementation: `internal/monitoring/metrics.go` - add counter/gauge

## Special Directories

**`cmd/relayer/`:**
- Purpose: Binary entry point
- Generated: No
- Committed: Yes

**`pkg/`:**
- Purpose: Reusable packages (merkle tree)
- Generated: No
- Committed: Yes

**Build Output:**
- `relayer`: Compiled binary
- Generated: Yes (from `go build`)
- Committed: No (in `.gitignore`)

**`/tmp/relayer-{nodeID}/`:**
- Purpose: Raft log and snapshot storage
- Generated: Yes (at runtime)
- Committed: No

---

*Structure analysis: 2026-03-13*
