//! BSC-specific transaction manager for handling Legacy transactions and BSC network optimizations.

use std::time::Duration;

use zksync_types::{
    eth_sender::EthTx,
    H256, U256,
};

use crate::{
    abstract_l1_interface::OperatorType,
    metrics::METRICS,
};

/// BSC-specific configuration for transaction management
#[derive(Debug, Clone)]
pub struct BSCTxManagerConfig {
    /// Whether to force legacy transaction format (BSC doesn't support EIP-1559)
    pub force_legacy_tx: bool,
    /// Maximum gas price in wei for BSC network
    pub max_gas_price_wei: U256,
    /// Base gas price for BSC network
    pub base_gas_price_wei: U256,
    /// Gas price multiplier for priority transactions
    pub priority_gas_multiplier: f64,
    /// Maximum number of confirmation blocks for BSC
    pub max_confirmation_blocks: u64,
    /// BSC block time in seconds
    pub block_time_seconds: u64,
    /// Whether to use fast confirmation mode
    pub fast_confirmation: bool,
}

impl Default for BSCTxManagerConfig {
    fn default() -> Self {
        Self {
            force_legacy_tx: true,
            max_gas_price_wei: U256::from(20_000_000_000u64), // 20 Gwei
            base_gas_price_wei: U256::from(5_000_000_000u64), // 5 Gwei
            priority_gas_multiplier: 1.1,
            max_confirmation_blocks: 15,
            block_time_seconds: 3,
            fast_confirmation: true,
        }
    }
}

impl BSCTxManagerConfig {
    /// Create configuration for BSC mainnet
    pub fn mainnet() -> Self {
        Self {
            max_gas_price_wei: U256::from(20_000_000_000u64), // 20 Gwei
            base_gas_price_wei: U256::from(5_000_000_000u64), // 5 Gwei
            ..Default::default()
        }
    }

    /// Create configuration for BSC testnet
    pub fn testnet() -> Self {
        Self {
            max_gas_price_wei: U256::from(50_000_000_000u64), // 50 Gwei
            base_gas_price_wei: U256::from(10_000_000_000u64), // 10 Gwei
            priority_gas_multiplier: 1.2, // Higher multiplier for testnet reliability
            max_confirmation_blocks: 10, // Fewer confirmations needed for testnet
            ..Default::default()
        }
    }

    /// Get recommended confirmation blocks based on transaction value
    pub fn get_confirmation_blocks(&self, tx_value: U256) -> u64 {
        BSCTxUtils::get_bsc_confirmation_blocks(self, tx_value)
    }
}

/// BSC transaction manager for handling BSC-specific transaction logic
#[derive(Debug)]
pub struct BSCTxManager {
    config: BSCTxManagerConfig,
}

impl BSCTxManager {
    /// Create new BSC transaction manager
    pub fn new(config: BSCTxManagerConfig) -> Self {
        Self { config }
    }

    /// Get BSC transaction manager configuration
    pub fn config(&self) -> &BSCTxManagerConfig {
        &self.config
    }

    /// Check if transaction should use legacy format
    pub fn should_use_legacy_tx(&self) -> bool {
        self.config.force_legacy_tx
    }

    /// Calculate gas price for BSC transaction
    pub fn calculate_gas_price(&self, base_price: U256, is_priority: bool) -> U256 {
        BSCTxUtils::calculate_bsc_gas_price(base_price, &self.config, is_priority)
    }

    /// Get confirmation blocks for transaction
    pub fn get_confirmation_blocks(&self, tx_value: U256) -> u64 {
        BSCTxUtils::get_bsc_confirmation_blocks(&self.config, tx_value)
    }
}

/// BSC-specific transaction utilities and helpers
pub struct BSCTxUtils;

impl BSCTxUtils {
    /// Calculate BSC-optimized gas price
    pub fn calculate_bsc_gas_price(
        base_price: U256,
        config: &BSCTxManagerConfig,
        is_priority: bool,
    ) -> U256 {
        let adjusted_base = std::cmp::max(base_price, config.base_gas_price_wei);
        
        let adjusted_price = if is_priority {
            let multiplier = (config.priority_gas_multiplier * 1000.0) as u64;
            adjusted_base * U256::from(multiplier) / U256::from(1000)
        } else {
            adjusted_base
        };

        // Cap at maximum gas price
        std::cmp::min(adjusted_price, config.max_gas_price_wei)
    }

    /// Get BSC-specific confirmation blocks based on transaction value
    pub fn get_bsc_confirmation_blocks(config: &BSCTxManagerConfig, tx_value: U256) -> u64 {
        if config.fast_confirmation {
            // For BSC, we can use fewer confirmations due to better finality
            if tx_value > U256::from(1_000_000_000_000_000_000u64) {
                // > 1 ETH equivalent, use more confirmations
                config.max_confirmation_blocks
            } else {
                // Smaller transactions can use fewer confirmations
                config.max_confirmation_blocks / 2
            }
        } else {
            config.max_confirmation_blocks
        }
    }

    /// Check if transaction should use legacy format for BSC
    pub fn should_use_legacy_tx(tx: &EthTx, config: &BSCTxManagerConfig) -> bool {
        config.force_legacy_tx || !Self::supports_eip1559(tx)
    }

    /// Check if the transaction supports EIP-1559 (BSC doesn't)
    fn supports_eip1559(_tx: &EthTx) -> bool {
        false // BSC doesn't support EIP-1559
    }



    /// Create BSC-specific operator type based on transaction
    pub fn get_bsc_operator_type(tx: &EthTx) -> OperatorType {
        // For BSC, we typically use NonBlob since BSC doesn't support blob transactions
        match tx.blob_sidecar {
            Some(_) => OperatorType::Blob, // This shouldn't happen on BSC, but handle it
            None => OperatorType::NonBlob,
        }
    }

    /// Log BSC transaction metrics
    pub fn log_bsc_transaction_sent(tx_hash: H256, gas_price: U256, operator_type: OperatorType) {
        METRICS.bsc_tx_sent.inc();
        METRICS.bsc_current_gas_price_gwei.set(gas_price.as_u64() as f64 / 1_000_000_000.0);
        
        if operator_type == OperatorType::NonBlob {
            METRICS.bsc_legacy_tx_used.inc();
        }

        tracing::info!(
            tx_hash = %tx_hash,
            gas_price_gwei = gas_price.as_u64() as f64 / 1_000_000_000.0,
            operator_type = ?operator_type,
            "BSC transaction sent with optimized parameters"
        );
    }

    /// Log BSC transaction confirmation
    pub fn log_bsc_transaction_confirmed(
        tx_hash: H256,
        confirmations: u64,
        duration: Duration,
    ) {
        METRICS.bsc_tx_confirmed.inc();
        METRICS.bsc_confirmation_duration.observe(duration);

        tracing::info!(
            tx_hash = %tx_hash,
            confirmations = confirmations,
            duration_ms = duration.as_millis(),
            "BSC transaction confirmed"
        );
    }
}

/// BSC network status information
#[derive(Debug, Clone)]
pub struct BSCNetworkStatus {
    pub chain_id: u64,
    pub current_block: u64,
    pub gas_price: U256,
    pub is_mainnet: bool,
    pub is_testnet: bool,
    pub block_time: u64,
    pub max_gas_price: U256,
}

impl BSCNetworkStatus {
    /// Check if gas price is within acceptable range
    pub fn is_gas_price_acceptable(&self) -> bool {
        self.gas_price <= self.max_gas_price
    }

    /// Get network name
    pub fn network_name(&self) -> &'static str {
        if self.is_mainnet {
            "BSC Mainnet"
        } else if self.is_testnet {
            "BSC Testnet"
        } else {
            "Unknown BSC Network"
        }
    }

    /// Get recommended confirmation blocks
    pub fn recommended_confirmations(&self) -> u64 {
        if self.is_mainnet {
            15 // More confirmations for mainnet
        } else {
            10 // Fewer confirmations for testnet
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bsc_config_creation() {
        let mainnet_config = BSCTxManagerConfig::mainnet();
        assert_eq!(mainnet_config.max_gas_price_wei, U256::from(20_000_000_000u64));
        assert_eq!(mainnet_config.base_gas_price_wei, U256::from(5_000_000_000u64));
        assert!(mainnet_config.force_legacy_tx);

        let testnet_config = BSCTxManagerConfig::testnet();
        assert_eq!(testnet_config.max_gas_price_wei, U256::from(50_000_000_000u64));
        assert_eq!(testnet_config.base_gas_price_wei, U256::from(10_000_000_000u64));
    }

    #[test]
    fn test_confirmation_blocks_calculation() {
        let config = BSCTxManagerConfig::mainnet();
        
        // Small transaction
        let small_tx_confirmations = config.get_confirmation_blocks(U256::from(100_000_000_000_000_000u64)); // 0.1 ETH
        assert_eq!(small_tx_confirmations, config.max_confirmation_blocks / 2);
        
        // Large transaction
        let large_tx_confirmations = config.get_confirmation_blocks(U256::from(2_000_000_000_000_000_000u64)); // 2 ETH
        assert_eq!(large_tx_confirmations, config.max_confirmation_blocks);
    }

    #[test]
    fn test_bsc_network_status() {
        let mainnet_status = BSCNetworkStatus {
            chain_id: zksync_types::web3::types::U64::from(56),
            current_block: 1000,
            gas_price: U256::from(5_000_000_000u64),
            is_mainnet: true,
            is_testnet: false,
            block_time: 3,
            max_gas_price: U256::from(20_000_000_000u64),
        };

        assert!(mainnet_status.is_gas_price_acceptable());
        assert_eq!(mainnet_status.network_name(), "BSC Mainnet");
        assert_eq!(mainnet_status.recommended_confirmations(), 15);
    }
}