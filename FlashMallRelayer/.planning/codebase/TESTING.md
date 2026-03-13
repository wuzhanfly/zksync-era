# Testing Patterns

**Analysis Date:** 2026-03-13

## Test Framework

**Runner:**
- Go testing package (built-in)
- Command: `go test -v -race ./...`

**Test Location:**
- Test files co-located with source using `*_test.go` suffix
- Example: `internal/common/validation.go` would have `internal/common/validation_test.go`

**Current State:** No test files exist in the codebase - this is a significant gap

## Run Commands

```bash
# Run all tests
go test -v -race ./...

# Run with coverage
go test -v -race -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

## Test File Organization

**Location Pattern:**
- Tests should be in same package as implementation
- Co-located with source files

**Naming:**
- `*_test.go` suffix
- Example: `trade_handler_test.go`, `client_test.go`

**Structure (Expected):**
```
internal/
├── relayer/
│   ├── trade_handler.go
│   └── trade_handler_test.go
├── common/
│   ├── validation.go
│   └── validation_test.go
└── config/
    ├── config.go
    └── config_test.go
```

## Test Structure

**Expected Pattern (not currently in codebase):**

```go
package relayer

import (
	"testing"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewTradeHandler(t *testing.T) {
	// Arrange
	cfg := &config.RelayerConfig{
		MaxPendingTx: 100,
	}

	// Act
	handler := NewTradeHandler(l2Client, l1Client, redis, metrics, cfg)

	// Assert
	require.NotNil(t, handler)
	assert.Equal(t, 100, cap(handler.tradeQueue))
}
```

## Mocking

**Framework:** Not currently used - no mocking framework in dependencies

**Recommended Approach (not implemented):**
- Use interfaces for dependencies
- Create mock implementations for testing
- Example interfaces in codebase:
```go
type ClientInterface interface {
	BlockNumber() (uint64, error)
	BlockByNumber(*big.Int) (*types.Block, error)
	TransactionReceipt(hash common.Hash) (*types.Receipt, error)
}
```

**Mock Pattern (Expected):**
```go
type MockClient struct {
	BlockNumberFunc func() (uint64, error)
}

func (m *MockClient) BlockNumber() (uint64, error) {
	return m.BlockNumberFunc()
}
```

## Fixtures and Factories

**Test Data:** Not currently present in codebase

**Expected Location:**
- Test data can be defined in test files
- For complex data, create `testdata/` directory

**Example (Expected):**
```go
func TestTradeValidation(t *testing.T) {
	tests := []struct {
		name    string
		trade   *TradeEvent
		wantErr bool
	}{
		{
			name: "valid trade",
			trade: &TradeEvent{
				User:     common.HexToAddress("0x123"),
				Merchant: common.HexToAddress("0x456"),
				Amount:   big.NewInt(1000),
			},
			wantErr: false,
		},
	}
	// ...
}
```

## Coverage

**Current State:** Not enforced

**Expected Target:** 70%+ for core business logic

**View Coverage:**
```bash
go test -v -race -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

## Test Types

**Unit Tests:**
- Test individual functions and methods
- Should not require external services (use mocks)

**Integration Tests:**
- Test interactions between components
- May require Redis, PostgreSQL, L1/L2 endpoints

**Not Implemented:**
- E2E tests not present
- No test framework for blockchain interactions

## Common Patterns (To Implement)

**Async Testing:**
```go
func TestAsyncOperation(t *testing.T) {
	done := make(chan error, 1)
	go func() {
		done <- asyncFunc()
	}()

	select {
	case err := <-done:
		require.NoError(t, err)
	case <-time.After(5 * time.Second):
		t.Fatal("timeout")
	}
}
```

**Error Testing:**
```go
func TestErrorHandling(t *testing.T) {
	tests := []struct {
		name      string
		input     string
		wantErr   bool
		errString string
	}{
		{
			name:      "invalid address",
			input:     "invalid",
			wantErr:   true,
			errString: "invalid Ethereum address",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateAddress(tt.input)
			if tt.wantErr {
				require.Error(t, err)
				assert.Contains(t, err.Error(), tt.errString)
			} else {
				require.NoError(t, err)
			}
		})
	}
}
```

## What Needs Testing

**Critical Areas:**
1. `internal/relayer/trade_handler.go` - Trade processing logic
2. `internal/common/validation.go` - Input validation
3. `internal/common/errors.go` - Error handling
4. `internal/config/config.go` - Config loading and validation
5. `internal/l2/client.go` - L2 client operations
6. `internal/l1/client.go` - L1 client operations

**Test Gaps:**
- No test files exist
- No mocking infrastructure
- No test utilities
- No test fixtures

---

*Testing analysis: 2026-03-13*
