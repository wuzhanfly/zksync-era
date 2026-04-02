# Coding Conventions

**Analysis Date:** 2026-04-02

## Naming Patterns

**Files:**
- Rust: `snake_case.rs` (e.g., `db_connection.rs`, `eth_sender_dal.rs`)
- TypeScript: `camelCase.ts` for implementation, `.test.ts` for tests
- Directory structure follows crate/module name

**Functions:**
- Rust: `snake_case` (e.g., `parse_h256()`, `ceil_div_u256()`)
- TypeScript: `camelCase` (e.g., `extractBytecode()`, `readContract()`)
- Constructor functions named `new()` for Rust structs
- Builder pattern methods prefixed with `with_` (e.g., `with_args()`, `with_log_directives()`)

**Variables:**
- Rust: `snake_case` for all variables
- TypeScript: `camelCase` (e.g., `testMaster`, `counterFactory`)
- Constants in UPPERCASE_SNAKE_CASE across both languages

**Types:**
- Rust: `PascalCase` for structs, enums, and types (e.g., `AccountTreeId`, `DalError`)
- TypeScript: `PascalCase` for types and interfaces
- Type aliases: `PascalCase` (e.g., `DalResult<T>`, `SerialId`)

## Code Style

**Formatting:**
- Rust: Standard `rustfmt` formatting
- TypeScript: Prettier with custom config at `/.prettierrc.js`
  - `printWidth: 120`
  - `singleQuote: true`
  - `trailingComma: 'none'`
  - `tabWidth: 4`

**Solidity (in contracts/):**
- Prettier with `prettier-plugin-solidity`
- `printWidth: 120`, `singleQuote: false`, `tabWidth: 4`, `bracketSpacing: false`

**Linting:**
- Rust: Clippy with warnings enabled
  - `#![warn(clippy::cast_lossless)]`
  - `#![allow(clippy::upper_case_acronyms)]`
- TypeScript: ESLint via `@matterlabs/eslint-config-typescript`

## Import Organization

**Order (Rust):**
1. Standard library imports (`std::*`)
2. External crate imports (anyhow, serde, etc.)
3. Local workspace imports (re-exports from `pub use`)
4. Module declarations (private or pub `mod`)
5. Type aliases and constants

**Example:**
```rust
use std::{
    convert::{Infallible, TryFrom, TryInto},
    fmt,
    num::ParseIntError,
    ops::{Add, Deref, DerefMut, Sub},
    str::FromStr,
};

use anyhow::Context as _;
pub use ethabi::{...};
use serde::{de, Deserialize, Deserializer, Serialize};

#[macro_use]
mod macros;
pub mod basic_fri_types;
pub mod bytecode;
mod conversions;
```

**Order (TypeScript):**
1. Framework/lib imports
2. Interface/type declarations
3. Function definitions
4. Exports

## Error Handling

**Rust Error Strategy:**
- Primary: `anyhow::Error` with context
  - Pattern: `.context("failed doing X")?`
- Custom errors: `thiserror::Error` for domain-specific errors
  - Example: `DalError`, `DalRequestError`, `DalConnectionError` in `core/lib/db_connection/src/error.rs`
- Result type aliases: `DalResult<T> = Result<T, DalError>`

**Special Error Type - OrStopped:**
- `OrStopped::Internal(E)` for actual errors
- `OrStopped::Stopped` for clean task termination
- Trait `StopContext<T>` provides `.stop_context(msg)` and `.unwrap_stopped(value)`

**TypeScript:**
- Standard try/catch with error logging
- `expect()` for test assertions

## Logging

**Framework:** Tracing/Tracing-subscriber via `zksync_vlog` crate

**Log Levels:**
- Default: `zksync=info`
- Override: `RUST_LOG` environment variable

**Log Formats:**
- `LogFormat::Plain` - Human readable (default)
- `LogFormat::Json` - Machine readable

**Patterns:**
```rust
tracing::info!("message");
tracing::warn!("Failed {action_name}: {err:?}");
tracing::error!("Panicked while {action_name}");
```

## Module Design

**Exports:**
- Re-export commonly used types at crate root via `pub use`
- Mark private modules with `mod` (not `pub mod`)

**Barrel Files:**
- `lib.rs` re-exports main types and submodules
- Submodules organized as `pub mod submodule_name;`

**Module Organization:**
- DAL: Split by entity (e.g., `blocks_dal.rs`, `transactions_dal.rs`)
- Libraries: Organized by domain
- Dedicated `metrics.rs`, `error.rs`, or `helpers.rs` per module

## Derive Macros

**Common Derive Stack:**
```rust
#[derive(Debug, Clone, Copy, Eq, PartialEq, Serialize, Deserialize, Hash, Ord, PartialOrd)]
pub struct AccountTreeId { ... }
```

**Framework-specific:**
- `#[derive(FromContext)]` - Node framework dependency injection
- `#[derive(IntoContext)]` - Node framework resource insertion
- `#[derive(thiserror::Error)]` - Custom error types
- `#[derive(Parser)]` - CLI argument parsing (clap)

## Function Design

**Parameters:**
- Use newtype structs for domain-specific identifiers (e.g., `L2ChainId`, `L1BatchNumber`)
- Builder pattern with `with_*` methods for optional parameters

**Return Values:**
- `anyhow::Result<T>` for fallible operations
- Type aliases for frequent types: `pub type DalResult<T> = Result<T, DalError>`

**Async/Await:**
- `tokio` runtime throughout
- Async trait methods via `async_trait` crate
