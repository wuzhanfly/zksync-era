# Coding Conventions

**Analysis Date:** 2026-03-13

## Language

**Primary:**
- Go 1.23.10 - All application code

## Naming Patterns

**Files:**
- Use snake_case: `trade_handler.go`, `postgres.go`, `merkle_tree.go`
- Test files use `*_test.go` suffix

**Types:**
- Use PascalCase: `TradeHandler`, `Client`, `Config`, `RelayerError`
- Interfaces often end with "er": `Client`, `Server`

**Functions:**
- Exported functions use PascalCase: `NewClient`, `Load`, `Validate`
- Unexported functions use camelCase: `connect`, `enqueueTrade`, `worker`
- Constructor functions named `NewXxx()`: `NewClient`, `NewServer`, `NewTradeHandler`

**Variables:**
- Use camelCase: `rpcURL`, `chainID`, `tradeQueue`
- Unused variables should be explicitly discarded with `_`

**Constants:**
- Grouped constants use iota with prefix: `ErrCodeInvalidParams ErrorCode = iota`
- Named constants use PascalCase or SCREAMING_SNAKE_CASE

**Packages:**
- Use short, lowercase names: `relayer`, `common`, `config`, `storage`

## Code Style

**Formatting:**
- Uses Go standard formatting via `go fmt`
- Run: `go fmt ./...`

**Linting:**
- Uses golangci-lint
- Run: `golangci-lint run`
- Configuration: Not present (uses defaults)

**Struct Tags:**
- JSON tags use camelCase: `json:"l2_tx_hash"`
- Config tags use mapstructure: `mapstructure:"rpc_url"`

## Import Organization

**Order (grouped by blank line):**
1. Standard library: `context`, `fmt`, `time`, `sync`
2. External packages: `github.com/...`, `github.com/ethereum/...`
3. Local packages: `github.com/fm4-relayer/relayer/...`

**Example:**
```go
import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/gin-gonic/gin"

	relayerCommon "github.com/fm4-relayer/relayer/internal/common"
	"github.com/fm4-relayer/relayer/internal/config"
)
```

## Error Handling

**Custom Error Type:**
- Defined in `internal/common/errors.go`
- Uses `RelayerError` struct with error codes:
```go
type RelayerError struct {
	Code    ErrorCode `json:"code"`
	Message string    `json:"message"`
	Cause   error     `json:"cause,omitempty"`
}
```

**Error Codes:**
- Defined as constants with iota: `ErrCodeInvalidParams`, `ErrCodeNodeDisconnected`
- Error messages stored in map for lookup

**Error Construction:**
- Factory functions: `InvalidParams()`, `NodeDisconnected()`, `InsufficientBalance()`
- Uses `NewRelayerError(code, cause)` pattern
- Wraps errors with `%w`: `fmt.Errorf("failed to dial RPC: %w", err)`

**Error Checking:**
- Use `errors.Is()` or `errors.As()` for wrapped errors
- `IsRetryable()` method on RelayerError for retry logic

**Pattern Example:**
```go
func NewClient(rpcURL string) (*Client, error) {
	rpcClient, err := rpc.DialContext(ctx, rpcURL)
	if err != nil {
		return nil, fmt.Errorf("failed to dial RPC: %w", err)
	}
	return &Client{rpcClient: rpcClient}, nil
}
```

## Logging

**Framework:** Standard Go `log` package

**Configuration:**
```go
log.SetFlags(log.LstdFlags | log.Lshortfile)
log.SetOutput(os.Stdout)
```

**Patterns:**
- Emoji prefixes for status: "Starting", "Stopping", "Error"
- Example: `log.Println("Starting FM4 Relayer...")`
- Errors use `log.Fatalf` or `log.Printf`

**Log Levels:**
- Not used - all logs go to stdout
- Use emojis to indicate severity:
  - `🚀` - Startup
  - `✅` - Success
  - `❌` - Error/Failure
  - `⚠️` - Warning
  - `📡` - Listening
  - `👷` - Processing

## Comments

**When to Comment:**
- Exported functions should have doc comments
- Complex business logic needs explanation
- Non-obvious behavior should be documented

**Style:**
- Use full sentences for exported functions
- Inline comments for implementation details

**Example:**
```go
// NewClient creates a new L2 client and connects to the RPC endpoint
func NewClient(rpcURL string, chainID uint64) (*Client, error) {
	// Test connection before returning
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	...
}
```

## Function Design

**Size:** No strict limit, but prefer small focused functions

**Parameters:**
- Group related parameters into structs for clarity
- Use interfaces for dependency injection
- Context should be first parameter for cancellable operations

**Return Values:**
- Return error as last return value
- Use named returns for clarity when helpful

**Pattern Example:**
```go
func (c *Client) BlockByNumber(number *big.Int) (*types.Block, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	block, err := c.client.BlockByNumber(ctx, number)
	if err != nil {
		return nil, fmt.Errorf("failed to get block: %w", err)
	}
	return block, nil
}
```

## Module Design

**Package Structure:**
- `cmd/` - Entry points
- `internal/` - Private application code
- `pkg/` - Reusable packages
- `internal/relayer/` - Core business logic
- `internal/common/` - Shared types and utilities
- `internal/config/` - Configuration
- `internal/storage/` - Storage clients
- `internal/l1/`, `internal/l2/` - Chain clients
- `internal/server/` - HTTP server
- `internal/monitoring/` - Metrics and monitoring

**Exports:**
- Only export what's needed externally
- Use unexported (lowercase) for internal implementation

**Barrel Files:** Not used - imports use full paths

## Validation

**Pattern:**
- Uses `ValidationResult` struct in `internal/common/validation.go`:
```go
type ValidationResult struct {
	Valid   bool
	Message string
}
```

**Functions:**
- Named `ValidateXxx()` returning `ValidationResult`
- Examples: `ValidateEthAddress()`, `ValidateTxHash()`, `ValidateAmount()`

## Configuration

**Framework:** Viper (github.com/spf13/viper)

**Pattern:**
- Structs with `mapstructure` tags
- Default values set via `viper.SetDefault()`
- Environment variables with prefix via `viper.SetEnvPrefix()`

**Example:**
```go
type Config struct {
	L2 ChainConfig `mapstructure:"l2"`
}

func Load() *Config {
	viper.SetDefault("relayer.log_level", "info")
	viper.SetEnvPrefix("RELAYER")
	viper.AutomaticEnv()
	// ...
}
```

---

*Convention analysis: 2026-03-13*
