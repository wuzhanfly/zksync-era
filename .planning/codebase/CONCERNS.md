# Codebase Concerns

**Analysis Date:** 2026-04-08

---

## BSC Adaptation: Duplicated Network Detection Logic

**Area:** `core/node/eth_sender/src/eth_fees_oracle.rs`, `core/lib/eth_client/src/clients/http/query.rs`, `core/node/eth_sender/src/network_aware/network_detector.rs`

- Issue: Network type detection from chain ID is implemented THREE times in three different places, each slightly different:
  1. `detect_network_type_from_env()` in `eth_fees_oracle.rs` — reads `L1_CHAIN_ID` env var
  2. `detect_bsc_network_from_env()` in `query.rs` — reads `L1_CHAIN_ID` env var, falls back to parsing `L1_RPC_URL` for "bsc"/"binance"/"bnb" strings
  3. `detect_network_type()` in `network_detector.rs` — takes `L1ChainId` as parameter (correct approach)
- Impact: Inconsistency when env vars are missing; URL-based heuristic in `query.rs` is fragile and untested. Changes to one detection path do not propagate to others.
- Fix approach: Remove `detect_network_type_from_env()` and `detect_bsc_network_from_env()`. Pass `L1ChainId` (already available in config) through to call sites, using the canonical `detect_network_type()` from `network_detector.rs`.

---

## BSC Adaptation: Dead Code — `bsc_fee_config.rs` Not Wired In

**Area:** `core/node/eth_sender/src/bsc_fee_config.rs`

- Issue: `BscFeeOptimizationConfig` struct with full implementation including `from_env()`, `validate()`, and tests exists in `bsc_fee_config.rs`, but the file is never declared as a module in `lib.rs`. It is completely dead code and is never used anywhere in the codebase.
- Impact: Developers may assume this config is active when it is not. Any env vars like `BSC_MIN_BASE_FEE`, `BSC_MAX_BASE_FEE` etc. are silently ignored.
- Fix approach: Either wire `mod bsc_fee_config;` into `lib.rs` and integrate with `BscGasPriceProvider`, or delete the file entirely.

---

## BSC Adaptation: Dead Code — `network_aware_factory.rs` Not Wired In

**Area:** `core/node/eth_sender/src/network_aware_factory.rs`

- Issue: `create_network_aware_fees_oracle()` factory function exists but is never called anywhere in the codebase. The `NetworkAwareFeesOracle` it would create is also never instantiated in production paths. The actual fee oracle constructed in `EthTxManager::new()` (`core/node/eth_sender/src/eth_tx_manager.rs:65`) always creates `GasAdjusterFeesOracle` directly, which itself embeds the BSC logic via `detect_network_type_from_env()`. The two BSC fee paths coexist without connection.
- Impact: Architectural confusion about which code path is actually active.
- Fix approach: Remove `network_aware_factory.rs` and `network_aware/fees_oracle.rs` if the BSC logic in `eth_fees_oracle.rs` is the intended path; or refactor to use the factory pattern consistently.

---

## BSC Adaptation: `tokio::task::block_in_place` Used in Sync Fee Trait

**Area:** `core/node/eth_sender/src/eth_fees_oracle.rs` — lines 235, 252, 261, 315, 369, 692

- Issue: The `EthFeesOracle::calculate_fees()` trait method is synchronous (takes `&self`, no `async`). The BSC fallback path calls `self.bsc_provider.get_optimized_gas_price().await` by wrapping in `tokio::task::block_in_place(|| Handle::current().block_on(...))`. This is called at least 6 times for different fee types.
- Impact: `block_in_place` requires a multi-threaded tokio runtime and will panic on `current_thread` runtimes. It stalls the worker thread during fee calculation. Also introduces nesting risk if called from within an already-blocked context.
- Fix approach: Make `calculate_fees` async on the trait, or pre-compute BSC prices asynchronously and cache them so the synchronous fallback can read from a cached value.

---

## BSC Adaptation: `GasAdjusterFeesOracle` Struct Has Public `bsc_provider` Field

**Area:** `core/node/eth_sender/src/eth_fees_oracle.rs:212`

- Issue: `pub bsc_provider: BscGasPriceProvider` is a public field on `GasAdjusterFeesOracle`, which means it is part of the struct's public API but `GasAdjusterFeesOracle` itself is `pub(crate)`. The `NetworkAwareFeesOracle` in `network_aware/fees_oracle.rs` constructs a `GasAdjusterFeesOracle` at line 47 **without** the `bsc_provider` field — this will cause a compile error (missing field). However the module is `pub mod network_aware` but `fees_oracle.rs` inside it is never included in `network_aware/mod.rs`, so the dead code is never compiled.
- Impact: If someone adds `pub mod fees_oracle;` to `network_aware/mod.rs`, it will fail to compile.
- Fix approach: Either add `bsc_provider` to the `NetworkAwareFeesOracle` inner construction, or make `bsc_provider` private with a constructor.

---

## BSC Adaptation: `get_pending_block_base_fee_per_gas` Panics on BSC

**Area:** `core/lib/eth_client/src/clients/http/query.rs:127`

- Issue: `get_pending_block_base_fee_per_gas()` calls `block.base_fee_per_gas.unwrap()` with no error handling. BSC did not have `base_fee_per_gas` in block headers prior to BEP-95/BEP-336 activation, and some BSC nodes may omit this field. If `base_fee_per_gas` is `None`, this panics.
- Impact: Hard crash if BSC node returns a block without `base_fee_per_gas`. This function is called during transaction signing when `max_fee_per_gas` is not explicitly set.
- Fix approach: Return `EnrichedClientError` instead of panicking; add BSC-aware fallback to a default gas price.

---

## BSC Adaptation: `calculate_fees_with_blob_sidecar` Has Panic-Prone `unwrap()` on `blob_base_fee_per_gas`

**Area:** `core/node/eth_sender/src/eth_fees_oracle.rs:492,500`

- Issue: In the blob resend path, `previous_sent_tx.blob_base_fee_per_gas.unwrap()` is called without a guard. This `Option<u64>` will be `None` if the original transaction was a non-blob transaction that somehow ended up in the blob resend path. The comment says "This commonly happens on BSC where blob fees and base fees remain stable across blocks."
- Impact: Panic if a non-blob tx history is passed to blob fee calculation path.
- Fix approach: Replace with `unwrap_or(0)` or propagate the error path properly with a check that `previous_sent_tx` is actually a blob transaction before entering this branch.

---

## BSC Adaptation: Fusaka Config Is Fragile — BSC Relies on `fusaka_upgrade_block: 999999999`

**Area:** `tmai_ecosystem/chains/tmai_chain/configs/general.yaml:110`

- Issue: BSC support requires `use_fusaka_blob_format: false` (BSC doesn't support EIP-7594 cell proofs). This is enforced by setting `fusaka_upgrade_block: 999999999` — a far-future block number — to prevent Fusaka from ever being considered "Finished". This is a fragile sentinel value, not a proper "disabled" flag.
- Impact: If BSC ever upgrades and the block number passes 999999999 (unlikely in the next decade, but not impossible), Fusaka blob format will silently activate on BSC, breaking blob submissions. Additionally, other configs (`general_bsc_optimized.yaml` and `general_high_tps.yaml`) have `use_fusaka_blob_format: true`, which contradicts the BSC requirement.
- Fix approach: Add an explicit `fusaka_disabled: true` config option or ensure `fusaka_upgrade_block: null` properly means "never". Audit and unify the duplicate yaml config files.

---

## BSC Adaptation: Contradictory Config Files

**Area:** `tmai_ecosystem/chains/tmai_chain/configs/`

- Issue: Three `general.yaml` variants exist for the same chain:
  - `general.yaml` — has `use_fusaka_blob_format: false` (correct for BSC)
  - `general_bsc_optimized.yaml` — has `use_fusaka_blob_format: true` (WRONG for BSC)
  - `general_high_tps.yaml` — has `use_fusaka_blob_format: true` (WRONG for BSC)
- Impact: Using the wrong config file will silently enable Fusaka blob format which BSC does not support (cell proofs), causing blob submission failures.
- Fix approach: Remove or clearly document which config is authoritative. Add a startup validation that asserts `use_fusaka_blob_format: false` on BSC chain IDs.

---

## BSC Adaptation: `bsc_fee_optimization` Config Block Parsed Nowhere

**Area:** `tmai_ecosystem/chains/tmai_chain/configs/general.yaml:39-44`

- Issue: The YAML config contains a `bsc_fee_optimization` section with `enabled`, `max_base_fee_gwei`, `min_base_fee_gwei`, `network_type`, `target_base_fee_gwei`. There is no corresponding Rust config struct in `core/lib/config/` that parses these fields. The `BscFeeOptimizationConfig` in `bsc_fee_config.rs` reads from env vars, not from this YAML section, and is itself dead code.
- Impact: All BSC fee tuning via YAML is silently ignored. Operators have no way to tune BSC fee behavior through config files.
- Fix approach: Either create a `BscFeeOptimizationConfig` config struct in `core/lib/config/src/configs/` and wire it into the gas adjuster, or remove the dead YAML section to avoid confusion.

---

## BSC Adaptation: Fee Cap Inconsistency — BSC Non-Blob Uses Hardcoded 20 Gwei Default

**Area:** `core/node/eth_sender/src/network_aware/fees_oracle.rs:16-17`

- Issue: `BSC_DEFAULT_GAS_PRICE = 20_000_000_000` (20 Gwei) is hardcoded as the default for non-blob BSC transactions, but `BscFeeConfig` in `eth_fees_oracle.rs` uses 1 Gwei as the target. There are now two different default BSC gas prices in the codebase, neither connected to configuration.
- Impact: Non-blob BSC transactions may pay 20x more than necessary on an idle network.
- Fix approach: Consolidate to a single configurable default. Use actual gas adjuster readings from the BSC node rather than hardcoded constants.

---

## Tech Debt: FIXME in Production Code — `call_results_iterator.next().unwrap()`

**Area:** `core/node/eth_sender/src/eth_tx_aggregator.rs:500`

- Issue: `call_results_iterator.next().unwrap(); // FIXME: why is this value requested?` — a value is consumed from a multicall result iterator with an explicit FIXME comment and no understanding of why.
- Impact: If the multicall ABI changes and this position shifts, the result parsing will silently read the wrong values for all subsequent fields.
- Fix approach: Investigate the multicall encoding to determine whether this slot is needed and document it, or remove the call if it is not.

---

## Tech Debt: `TODO calculate it properly` in Publish Criterion

**Area:** `core/node/eth_sender/src/publish_criterion.rs:336`

- Issue: Comment `/// TODO calculate it properly` on a gas calculation method. Indicates a value is being estimated rather than precisely computed.
- Impact: Potentially suboptimal gas usage when aggregating L1 transactions on BSC.
- Fix approach: Implement proper gas calculation using actual BSC gas costs.

---

## Security: env Var Race Condition in Network Detection

**Area:** `core/node/eth_sender/src/eth_fees_oracle.rs:40-54`, `core/lib/eth_client/src/clients/http/query.rs:21-36`

- Issue: `L1_CHAIN_ID` environment variable is read on every call to `detect_network_type_from_env()` and `detect_bsc_network_from_env()`, which are called inside hot paths (every fee calculation, every fee history fetch). `std::env::var()` acquires a lock on the environment on some platforms. In the tests, `std::env::set_var` and `std::env::remove_var` are used without synchronization, which in Rust 1.x is undefined behavior in multi-threaded tests.
- Impact: Potential data race in tests; performance overhead per fee calculation; and a theoretical security issue if env vars can be mutated at runtime.
- Fix approach: Cache the detected network type at startup (pass `L1ChainId` from config, already available). Remove all `std::env::var("L1_CHAIN_ID")` calls from fee calculation hot paths.

---

## Test Coverage Gaps

**Untested area: BSC fee oracle paths**
- What's not tested: `calculate_bsc_optimized_fees()`, `assert_fee_is_not_zero()` BSC branch, `check_priority_fee()` BSC branch, `detect_network_type_from_env()` with actual chain IDs in `eth_fees_oracle.rs`. The only BSC oracle test is in `network_aware/fees_oracle.rs` which tests the dead `NetworkAwareFeesOracle`, not the actually-used `GasAdjusterFeesOracle` BSC path.
- Files: `core/node/eth_sender/src/eth_fees_oracle.rs`, `core/node/eth_sender/src/tests.rs`
- Risk: BSC fee regressions are invisible. The standard test suite always runs with `NetworkType::Ethereum` (default when `L1_CHAIN_ID` is unset).
- Priority: High

**Untested area: BSC `fee_history` padding logic**
- What's not tested: The BSC-specific padding in `l1_base_fee_history()` in `core/lib/eth_client/src/clients/http/query.rs` (lines 368-454) — the short-array fill, truncation, and zero-padding for missing blob fees are not tested with a mock BSC node.
- Files: `core/lib/eth_client/src/clients/http/query.rs`
- Risk: Incorrect padding could cause `GasAdjuster` to work with garbage fee data, leading to under/over-priced transactions.
- Priority: High

---

## Performance: `block_in_place` Called Multiple Times Per Fee Calculation

**Area:** `core/node/eth_sender/src/eth_fees_oracle.rs` — up to 6 `block_in_place` calls possible in a single `calculate_fees()` invocation

- Problem: For BSC non-blob transactions, `calculate_bsc_optimized_fees()` calls `block_in_place` once. For BSC Gateway transactions, it calls `block_in_place` a second time. If `assert_fee_is_not_zero()` is triggered for both "base" and "priority" fees (i.e., if the adjuster returns zero for both), two more `block_in_place` calls occur. Each call re-runs the same `get_optimized_gas_price()` async computation.
- Cause: No caching between calls. `BscGasPriceProvider::get_optimized_gas_price()` calls `gas_adjuster.get_base_fee(0)` which is synchronous anyway — the `async` wrapper serves no purpose.
- Improvement path: Make `BscGasPriceProvider::get_optimized_gas_price()` synchronous (it only calls sync methods), removing all `block_in_place` uses entirely.

---

*Concerns audit: 2026-04-08*
