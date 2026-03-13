# External Integrations

**Analysis Date:** 2026-03-13

## APIs & External Services

**Blockchain L1 (BSC):**
- Binance Smart Chain (BSC) - L1 settlement
  - RPC URL: Configured in `configs/relayer.yaml` (default: `https://bsc-dataseed.binance.org`)
  - Chain ID: 56
  - Purpose: Submit processed trades, sync merkle roots
  - Auth: Private key via `L1_PRIVATE_KEY` env var
  - Client: `internal/l1/client.go`

**Blockchain L2 (zkSync Era):**
- zkSync Era Testnet - L2 execution
  - RPC URL: `https://testnet-node-0.maichain.org`
  - WebSocket: `wss://testnet-node-0.maichain.org/ws`
  - Chain ID: 9720
  - Purpose: Monitor L2 trades, fetch merkle proofs, block data
  - Client: `internal/l2/client.go`

**Smart Contracts:**
- L1Relayer.sol - Settlement contract on BSC
  - Address: Configured in `configs/relayer.yaml`
  - ABI: Defined in `internal/l1/client.go`
  - Functions: `processL2Trade`, `syncMerkleRoot`, `updateL2LatestBlock`

- L2TradeProxy.sol - Trade execution contract on zkSync
  - Address: Configured in `configs/relayer.yaml`
  - ABI: Defined in `internal/l2/client.go`
  - Events: `TradeExecuted`

## Data Storage

**PostgreSQL:**
- Provider: PostgreSQL 15 (Alpine)
- Connection: `postgres:5432` (Docker Compose)
- Database: `relayer`
- User: `relayer`
- Auth: `POSTGRES_PASSWORD` env var
- Client: `github.com/jackc/pgx/v5`
- Location: `internal/storage/postgres.go`
- Purpose: Persistent trade records, transaction history

**Redis:**
- Provider: Redis 7 (Alpine)
- Cluster: 3-node setup (redis-1, redis-2, redis-3)
- Ports: 6379, 6380, 6381
- Auth: `REDIS_PASSWORD` env var
- Client: `github.com/go-redis/redis/v8`
- Location: `internal/storage/redis.go`
- Purpose:
  - Distributed state management
  - Trade processing queue
  - Raft consensus storage
  - Caching

**File Storage:**
- Local filesystem (Docker volumes)
- Location: `/app/data` inside containers
- Purpose: Raft snapshots, application data

## Authentication & Identity

**Wallet-based Auth:**
- Private key authentication for L1 transactions
- Implementation: `crypto.HexToECDSA` from go-ethereum
- Address derived from private key
- Used in: `internal/l1/client.go`

## Monitoring & Observability

**Prometheus Metrics:**
- Framework: prometheus/client_golang
- Port: 9090 (configurable)
- Location: `internal/monitoring/metrics.go`
- Metrics exported:
  - L1 submitted transactions
  - L1 confirmed/failed transactions
  - Block processing metrics
  - Health scores

**Alerting:**
- Telegram Bot Notifications
  - Bot token: `TELEGRAM_BOT_TOKEN` env var
  - Chat ID: `TELEGRAM_CHAT_ID` env var
  - Implementation: `internal/monitoring/alerter.go`
- Webhook Alerts
  - URL: `ALERT_WEBHOOK_URL` env var

**Profiling (Optional):**
- Port: 6060 (configurable)
- Enabled: `enable_profiling` in config

## CI/CD & Deployment

**Container Platform:**
- Docker - Container runtime
- Docker Compose - Orchestration
- Services: 3 relayer nodes, 3 Redis nodes, PostgreSQL, Nginx

**Load Balancing:**
- Nginx - HTTP load balancer
- Config: `docker/nginx.conf`
- Routes traffic to relayer cluster

**Infrastructure:**
- 3-node Raft cluster for consensus
- 3-node Redis cluster for distributed state
- Single PostgreSQL instance

## Environment Configuration

**Required env vars:**
- `L1_PRIVATE_KEY` - BSC wallet private key
- `REDIS_PASSWORD` - Redis cluster password
- `POSTGRES_PASSWORD` - PostgreSQL password

**Optional env vars:**
- `ALERT_WEBHOOK_URL` - Custom alert webhook
- `TELEGRAM_BOT_TOKEN` - Telegram bot token
- `TELEGRAM_CHAT_ID` - Telegram chat ID for alerts

## Webhooks & Callbacks

**Outgoing:**
- Alert webhook - Custom HTTP endpoint for alerts
  - URL: `ALERT_WEBHOOK_URL` env var
  - Triggered on: Errors, critical failures
  - Implementation: `internal/monitoring/alerter.go`

**Incoming:**
- None detected - This is a relayer, not a webhook receiver

---

*Integration audit: 2026-03-13*
