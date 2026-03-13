# Architecture

**Analysis Date:** 2026-03-13

## Pattern Overview

**Overall:** Event-Driven Microservice with Distributed Consensus

**Key Characteristics:**
- Event-driven trade processing pipeline from L2 to L1
- Raft-based distributed consensus for cluster coordination
- Redis-backed state management and pub/sub messaging
- HTTP API layer with Gin framework
- Prometheus metrics collection

## Layers

**Entry Point:**
- Location: `cmd/relayer/main.go`
- Triggers: Binary execution
- Responsibilities: Application bootstrap, service initialization, graceful shutdown coordination

**Configuration Layer:**
- Location: `internal/config/config.go`
- Contains: Viper-based YAML configuration with environment variable overrides
- Depends on: Viper, OS environment
- Used by: All services

**API Layer (HTTP Server):**
- Location: `internal/server/http.go`
- Contains: Gin-based HTTP server with routes and handlers
- Responsibilities: Health checks, trade submission, status queries, metrics endpoints
- Depends on: Relayer core, sync, monitoring

**Core Business Logic:**
- Location: `internal/relayer/trade_handler.go`
- Contains: Trade processing workers, L2 event listening, L1 transaction submission
- Responsibilities: Event capture, Merkle proof retrieval, L1 finalization, retry handling

**Blockchain Abstraction Layer:**
- L1 Client: `internal/l1/client.go` - L1 Ethereum interaction (contract calls, transactions)
- L2 Client: `internal/l2/client.go` - L2 zkSync interaction (event parsing, Merkle proofs)
- Contains: RPC clients, ABI encoding, wallet signing, gas estimation
- Both implement similar interfaces for block/tx/receipt operations

**Distributed Consensus:**
- Location: `internal/cluster/raft.go`
- Contains: HashiCorp Raft node implementation, FSM, snapshots
- Responsibilities: Leader election, cluster state management
- Uses: BoltDB for log storage

**State & Storage:**
- Location: `internal/storage/redis.go`
- Contains: Redis client, Lua scripts, trade queue, node status
- Responsibilities: Trade persistence, idempotency checks, distributed locking

**Synchronization:**
- Location: `internal/sync/merkle_syncer.go`
- Contains: L2 block-to-L1 Merkle root synchronization
- Responsibilities: Block height tracking, periodic sync to L1

**Monitoring:**
- Location: `internal/monitoring/`
- Contains: Metrics (Prometheus), alerting

## Data Flow

**Trade Processing Flow:**

1. **Event Capture** - L2 client subscribes to new blocks or polls periodically
2. **Trade Detection** - Parse TradeExecuted events from L2 transactions
3. **Idempotency Check** - Redis check for processed trades
4. **Queue** - Enqueue trade for worker processing
5. **L2 Finality Wait** - Wait for confirmBlocks (default 15)
6. **Merkle Proof** - Build proof from L2 block transactions
7. **L1 Submission** - Submit processL2Trade to L1 relayer contract
8. **Confirmation** - Wait for L1 transaction receipt
9. **State Update** - Mark trade completed in Redis

**Sync Flow:**

1. **L2 Block Fetch** - Get latest L2 block via RPC
2. **Batch Processing** - Sync blocks in configurable batch size
3. **Merkle Root Extraction** - Get transaction root from L2 block
4. **L1 Update** - Submit syncMerkleRoot to L1 contract
5. **Confirmation** - Wait for L1 receipt
6. **L2 Latest Update** - Update L2 latest block number on L1

## Key Abstractions

**Blockchain Client Interface (implied):**
- Both L1 and L2 clients provide:
  - `BlockNumber()`, `BlockByNumber()`, `LatestBlock()`
  - `TransactionReceipt()`, `SendTransaction()`
  - `GasPrice()`, `EstimateGas()`
  - `SubscribeNewHead()`

**TradeHandler:**
- Purpose: Main trade processing coordinator
- Examples: `internal/relayer/trade_handler.go`
- Pattern: Worker pool with channel-based queue

**MerkleSyncer:**
- Purpose: Periodic L2-to-L1 block synchronization
- Examples: `internal/sync/merkle_syncer.go`
- Pattern: Background goroutine with ticker

## Entry Points

**Main Binary:**
- Location: `cmd/relayer/main.go`
- Triggers: `./relayer` or `go run cmd/relayer/main.go`
- Responsibilities: Config loading, service instantiation, lifecycle management

**HTTP API:**
- Location: `internal/server/http.go`
- Triggers: HTTP requests on configured port (default 8080)
- Responsibilities: Request handling, validation, response formatting

## Error Handling

**Strategy:** Per-layer error handling with retry awareness

**Patterns:**
- L2 events: Fallback from WebSocket subscription to polling
- Trade processing: Redis error storage with 24h TTL, metrics tracking
- L1 submission: Receipt status checking, revert detection
- RPC calls: Timeout with context, health score tracking

**Retry Approach:**
- TODO in `internal/relayer/trade_handler.go:316` - retry logic not fully implemented
- Current: Single attempt, errors logged to Redis

## Cross-Cutting Concerns

**Logging:** Standard Go log to stdout with timestamps and file/line

**Validation:**
- `internal/common/validation.go` - Ethereum address, transaction hash, amount validation
- Server request binding with Gin

**Authentication:**
- Optional API key auth in middleware
- Rate limiting with configurable RPS/burst

**Metrics:**
- Prometheus client in `internal/monitoring/metrics.go`
- Custom metrics: tx counts, latency, gas usage, block heights

---

*Architecture analysis: 2026-03-13*
