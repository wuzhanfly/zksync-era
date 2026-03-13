# Codebase Concerns

**Analysis Date:** 2026-03-13

## Tech Debt

**Incomplete Trade Submission:**
- Issue: Trade submission endpoint returns success without actually submitting to L2
- Files: `internal/server/http.go` (line 242)
- Impact: API returns false success, trades never processed
- Fix approach: Implement actual L2 trade submission logic

**Incomplete Trade Status Retrieval:**
- Issue: Status endpoint always returns PENDING without querying Redis
- Files: `internal/server/http.go` (line 261)
- Impact: Cannot retrieve actual trade status
- Fix approach: Implement Redis query for trade status

**Missing ABI Encoding/Decoding:**
- Issue: EncodeABI and DecodeABI functions return "not implemented" errors
- Files: `internal/common/utils.go` (lines 98-107)
- Impact: Cannot properly encode/decode contract calls
- Fix approach: Implement using go-ethereum abi.ABI type

**Missing Retry Logic:**
- Issue: Error handler has TODO comment for retry but no implementation
- Files: `internal/relayer/trade_handler.go` (line 316)
- Impact: Failed trades are not retried automatically
- Fix approach: Implement exponential backoff retry mechanism

**Typo in Contract Method Name:**
- Issue: Method name "processedL2Trakes" is misspelled
- Files: `internal/l1/client.go` (line 536)
- Impact: Contract call will fail
- Fix approach: Rename to "processedL2Trades"

## Known Bugs

**Rate Limiter Memory Leak:**
- Issue: Client map in rate limiter grows unbounded - old entries never cleaned up
- Files: `internal/server/middleware.go` (lines 90-132)
- Trigger: Long-running server with many unique IPs
- Workaround: Restart server periodically or implement cleanup

**Redis Ignores Multiple Addresses:**
- Issue: Redis client only uses first address despite accepting multiple addrs config
- Files: `internal/storage/redis.go` (lines 22-25)
- Impact: High availability config not utilized, single point of failure
- Workaround: Use single Redis instance or implement manual failover

**Lock Script Race Condition:**
- Issue: Lock acquire has race between NX and GET checks
- Files: `internal/storage/redis.go` (lines 67-84)
- Impact: Potential race condition in distributed locking
- Fix approach: Use single atomic SET with NX and EX options

**Empty Merkle Root Not Validated:**
- Issue: Syncer doesn't check for empty merkle root before submitting
- Files: `internal/sync/merkle_syncer.go` (line 168-172)
- Impact: Could submit invalid merkle roots to L1
- Workaround: Add validation for empty hash

**Event Parser Fixed Offsets:**
- Issue: Event parser uses hardcoded byte offsets without validation
- Files: `internal/l2/client.go` (lines 231-257)
- Impact: Parser will produce garbage if event structure changes
- Workaround: Add length checks and validation

## Security Considerations

**Hardcoded Credentials in Config:**
- Risk: Private keys and passwords use env variable placeholders but config may be logged
- Files: `configs/relayer.yaml`, `internal/config/config.go`
- Current mitigation: Uses ${VAR} placeholders
- Recommendations: Ensure config files are never logged, use env vars directly

**Insecure Default CORS:**
- Risk: Default TrustedOrigins allows all origins ("*")
- Files: `internal/server/http.go` (line 57)
- Current mitigation: None by default
- Recommendations: Restrict to specific origins in production

**Sensitive Data in Error Messages:**
- Risk: Sanitization exists but may not catch all sensitive data
- Files: `internal/common/validation.go` (lines 75-83)
- Current mitigation: Length limit of 500 chars
- Recommendations: Add regex patterns for common secret formats

**No Input Rate Limiting on Health Endpoints:**
- Risk: Health and ready endpoints unprotected from abuse
- Files: `internal/server/http.go` (lines 165-167)
- Recommendations: Add rate limiting to all endpoints

## Performance Bottlenecks

**Sequential Block Syncing:**
- Problem: Syncer processes blocks one at a time
- Files: `internal/sync/merkle_syncer.go` (lines 143-155)
- Cause: Loop processes each block serially
- Improvement path: Implement parallel block fetching and submission

**In-Memory Rate Limiter:**
- Problem: Unbounded map growth, no cleanup mechanism
- Files: `internal/server/middleware.go` (lines 90-132)
- Cause: No expiration or cleanup for old entries
- Improvement path: Add periodic cleanup or use fixed-size LRU cache

**Single Connection Pool Limit:**
- Problem: PostgreSQL max 25 connections may limit throughput
- Files: `internal/storage/postgres.go` (line 30)
- Improvement path: Increase pool size based on workload

**Small Default Batch Size:**
- Problem: Sync batch size of 10 may be too small for high throughput
- Files: `internal/sync/merkle_syncer.go` (line 41)
- Improvement path: Make configurable, increase default

## Fragile Areas

**Hardcoded Fallback Values:**
- Why fragile: Multiple hardcoded defaults (gas limits, prices) scattered in code
- Files: `internal/l1/client.go` (lines 301, 351, 407), `internal/server/http.go` (lines 291-294)
- Safe modification: Make configurable via config file

**Worker Pool Not Dynamic:**
- Why fragile: Fixed number of workers, cannot adapt to load
- Files: `internal/relayer/trade_handler.go` (lines 72-75)
- Safe modification: Add metrics-based autoscaling

**No Reconnection Logic:**
- Why fragile: L1/L2 clients don't reconnect after connection loss
- Files: `internal/l1/client.go`, `internal/l2/client.go`
- Safe modification: Add automatic reconnection with backoff

**Empty FSM Implementation:**
- Why fragile: Cluster FSM doesn't actually process commands
- Files: `internal/cluster/raft.go` (lines 240-268)
- Safe modification: Implement actual state machine logic

## Scaling Limits

**Current Capacity:**
- Max pending transactions: 10,000 (configurable)
- Worker count: 10 default (configurable)
- Rate limit: Configurable RPS (default 10)
- PostgreSQL pool: 25 connections
- Redis pool: 100 connections

**Where It Breaks:**
- High volume: Worker count may be insufficient for TPS spikes
- Rate limiting: In-memory implementation doesn't work across instances
- Database: Connection pool limits concurrent queries

**Scaling Path:**
- Horizontal: Deploy multiple relayer instances (requires proper Redis HA)
- Worker scaling: Implement dynamic worker pool based on queue depth
- Rate limiting: Use Redis-based distributed rate limiter

## Dependencies at Risk

**Old go-ethereum Version:**
- Risk: Using v1.11.6 (released ~2023), may lack newer EIP support
- Impact: May not work with newer chains or features
- Migration plan: Upgrade to latest stable version

**Deprecated raft-boltdb:**
- Risk: Using raft-boltdb/v2, bolt store has known limitations
- Impact: May have concurrency issues under high load
- Migration plan: Consider alternatives like BadgerDB

**Outdated raft Library:**
- Risk: Using raft v1.7.3, newer versions have improvements
- Impact: May have stability issues
- Migration plan: Upgrade to latest v1.x

**Redis Client v8:**
- Risk: v8 is older, v9 available with better performance
- Impact: Connection pooling may be suboptimal
- Migration plan: Consider upgrading to go-redis/v9

## Missing Critical Features

**Trade Retry Mechanism:**
- Problem: Failed trades not automatically retried
- Blocks: Reliable trade processing under network failures

**Dead Letter Queue:**
- Problem: Permanently failed trades have no visibility
- Blocks: Manual intervention required for troubleshooting

**Graceful Shutdown:**
- Problem: In-flight trades may be lost on shutdown
- Blocks: Zero-downtime deployments

**Circuit Breaker:**
- Problem: No protection when L1/L2 RPC unavailable
- Blocks: Cascading failures under outages

**Transaction Deduplication:**
- Problem: No idempotency key for submitted L1 transactions
- Blocks: Safe retry without duplicate submissions

## Test Coverage Gaps

**No Unit Tests:**
- What's not tested: Core utility functions (validation, encoding, conversion)
- Files: `internal/common/` - entire directory
- Risk: Bugs in utility functions affect entire system
- Priority: High

**No Integration Tests:**
- What's not tested: L1/L2 client interactions, storage operations
- Files: `internal/l1/`, `internal/l2/`, `internal/storage/`
- Risk: Integration issues not caught before deployment
- Priority: High

**No Test Files:**
- What's not tested: All functionality
- Files: No `*_test.go` files found
- Risk: Any code change could break functionality
- Priority: Critical

---

*Concerns audit: 2026-03-13*
