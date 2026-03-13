# Technology Stack

**Analysis Date:** 2026-03-13

## Languages

**Primary:**
- Go 1.23.10 - Primary backend language
  - Module: `github.com/fm4-relayer/relayer`
  - Used for: All core logic, API server, blockchain clients

**Secondary:**
- Solidity - Smart contracts
  - Files: `contracts/L1Relayer.sol`, `contracts/L2TradeProxy.sol`
  - Used for: L1/L2 relayer and trade proxy contracts

## Runtime

**Environment:**
- Alpine Linux 3.19 - Production container runtime
- Go 1.21 (Docker builder) - Build environment

**Package Manager:**
- Go modules (v1.23.10)
- Lockfile: `go.sum` present

## Frameworks

**Core:**
- gin-gonic/gin v1.9.1 - HTTP REST API framework
  - Location: `internal/server/http.go`
  - Purpose: HTTP server, middleware, routing

- ethereum/go-ethereum v1.11.6 - Ethereum protocol implementation
  - Location: `internal/l1/client.go`, `internal/l2/client.go`
  - Purpose: L1 (BSC) and L2 (zkSync Era) blockchain interaction

**Clustering:**
- hashicorp/raft v1.7.3 - Consensus and leader election
  - Location: `internal/cluster/raft.go`
  - Purpose: Distributed cluster coordination

- hashicorp/raft-boltdb/v2 v2.3.1 - Raft log persistence
  - Purpose: BoltDB storage for Raft state

**Storage:**
- go-redis/redis/v8 v8.11.5 - Redis client
  - Location: `internal/storage/redis.go`
  - Purpose: Caching, distributed state, pub/sub

- jackc/pgx/v5 v5.5.1 - PostgreSQL driver
  - Location: `internal/storage/postgres.go`
  - Purpose: Persistent transaction storage

**Monitoring:**
- prometheus/client_golang v1.18.0 - Prometheus metrics
  - Location: `internal/monitoring/metrics.go`
  - Purpose: Metrics collection and exposition

**Configuration:**
- spf13/viper v1.18.2 - Configuration management
  - Location: `internal/config/config.go`
  - Purpose: YAML config loading, environment variable substitution

## Key Dependencies

**Critical:**
- `github.com/ethereum/go-ethereum v1.11.6` - Blockchain interaction
- `github.com/gin-gonic/gin v1.9.1` - HTTP framework
- `github.com/hashicorp/raft v1.7.3` - Cluster consensus

**Storage:**
- `github.com/go-redis/redis/v8 v8.11.5` - Redis client
- `github.com/jackc/pgx/v5 v5.5.1` - PostgreSQL driver

**Observability:**
- `github.com/prometheus/client_golang v1.18.0` - Metrics

## Configuration

**Environment:**
- Configuration file: `configs/relayer.yaml`
- Environment variables required:
  - `L1_PRIVATE_KEY` - BSC private key for signing transactions
  - `REDIS_PASSWORD` - Redis cluster authentication
  - `POSTGRES_PASSWORD` - PostgreSQL authentication
  - `ALERT_WEBHOOK_URL` - Alert notification webhook
  - `TELEGRAM_BOT_TOKEN` - Telegram bot for alerts
  - `TELEGRAM_CHAT_ID` - Telegram chat for alerts

**Build:**
- Build command: `CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o relayer ./cmd/relayer`
- Dockerfile: `docker/Dockerfile`
- Multi-stage build using golang:1.21-alpine builder

## Platform Requirements

**Development:**
- Go 1.21+ compiler
- Docker and Docker Compose
- Access to BSC and zkSync Era testnet RPC endpoints

**Production:**
- Docker containerization
- 3-node Redis cluster (recommended)
- PostgreSQL 15
- Nginx for load balancing (see `docker/nginx.conf`)

---

*Stack analysis: 2026-03-13*
