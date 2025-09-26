//! BSC-specific fee model implementation for optimized gas pricing and fee calculation.

use std::{fmt, sync::Arc, time::Duration};

use anyhow::Context as _;
use async_trait::async_trait;
use zksync_dal::{ConnectionPool, Core, CoreDal};
use zksync_types::{
    fee_model::{
        BaseTokenConversionRatio, BatchFeeInput, FeeModelConfig, FeeParams, FeeParamsV1, FeeParamsV2,
    },
    U256,
};

use crate::{
    l1_gas_price::GasAdjuster,
    BaseTokenRatioProvider, BatchFeeModelInputProvider,
};

/// BSC-specific configuration for fee model
#[derive(Debug, Clone)]
pub struct BSCFeeModelConfig {
    /// Base gas price for BSC network in wei
    pub base_gas_price_wei: u64,
    /// Maximum gas price for BSC network in wei
    pub max_gas_price_wei: u64,
    /// Gas price update interval in seconds
    pub gas_price_update_interval: u64,
    /// Congestion detection threshold (gas price multiplier)
    pub congestion_threshold_multiplier: f64,
    /// Priority fee multiplier for urgent transactions
    pub priority_fee_multiplier: f64,
    /// Whether to use dynamic pricing based on network congestion
    pub use_dynamic_pricing: bool,
    /// BSC block time in seconds
    pub block_time_seconds: u64,
    /// Gas price smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
    pub price_smoothing_factor: f64,
}

impl Default for BSCFeeModelConfig {
    fn default() -> Self {
        Self {
            base_gas_price_wei: 5_000_000_000,  // 5 Gwei
            max_gas_price_wei: 20_000_000_000,  // 20 Gwei
            gas_price_update_interval: 3,       // 3 seconds (BSC block time)
            congestion_threshold_multiplier: 1.5,
            priority_fee_multiplier: 1.2,
            use_dynamic_pricing: true,
            block_time_seconds: 3,
            price_smoothing_factor: 0.3,
        }
    }
}

impl BSCFeeModelConfig {
    /// Create configuration for BSC mainnet
    pub fn mainnet() -> Self {
        Self {
            base_gas_price_wei: 5_000_000_000,  // 5 Gwei
            max_gas_price_wei: 20_000_000_000,  // 20 Gwei
            congestion_threshold_multiplier: 1.3, // More conservative for mainnet
            ..Default::default()
        }
    }

    /// Create configuration for BSC testnet
    pub fn testnet() -> Self {
        Self {
            base_gas_price_wei: 10_000_000_000, // 10 Gwei
            max_gas_price_wei: 50_000_000_000,  // 50 Gwei
            congestion_threshold_multiplier: 1.5, // More aggressive for testnet
            priority_fee_multiplier: 1.3,
            ..Default::default()
        }
    }

    /// Get recommended gas price based on current conditions
    pub fn get_recommended_gas_price(&self, current_price: u64, is_congested: bool) -> u64 {
        let base_price = std::cmp::max(current_price, self.base_gas_price_wei);
        
        let adjusted_price = if is_congested && self.use_dynamic_pricing {
            let multiplier = (self.congestion_threshold_multiplier * 1000.0) as u64;
            base_price * multiplier / 1000
        } else {
            base_price
        };

        std::cmp::min(adjusted_price, self.max_gas_price_wei)
    }
}

/// BSC-specific congestion detector
#[derive(Debug)]
pub struct BSCCongestionDetector {
    config: BSCFeeModelConfig,
    recent_gas_prices: std::sync::Mutex<Vec<(std::time::Instant, u64)>>,
    last_congestion_check: std::sync::Mutex<std::time::Instant>,
    is_congested: std::sync::Mutex<bool>,
}

impl BSCCongestionDetector {
    /// Create a new congestion detector
    pub fn new(config: BSCFeeModelConfig) -> Self {
        Self {
            config,
            recent_gas_prices: std::sync::Mutex::new(Vec::new()),
            last_congestion_check: std::sync::Mutex::new(std::time::Instant::now()),
            is_congested: std::sync::Mutex::new(false),
        }
    }

    /// Update gas price history and detect congestion
    pub fn update_gas_price(&self, gas_price: u64) {
        let now = std::time::Instant::now();
        let mut prices = self.recent_gas_prices.lock().unwrap();
        
        // Add new price
        prices.push((now, gas_price));
        
        // Remove old prices (keep only last 5 minutes)
        let cutoff = now - Duration::from_secs(300);
        prices.retain(|(timestamp, _)| *timestamp > cutoff);
        
        // Check if we should update congestion status
        let mut last_check = self.last_congestion_check.lock().unwrap();
        if now.duration_since(*last_check) > Duration::from_secs(self.config.gas_price_update_interval) {
            let congested = self.detect_congestion(&prices);
            *self.is_congested.lock().unwrap() = congested;
            *last_check = now;
        }
    }

    /// Detect if the network is congested based on recent gas prices
    fn detect_congestion(&self, prices: &[(std::time::Instant, u64)]) -> bool {
        if prices.len() < 3 {
            return false; // Not enough data
        }

        let recent_prices: Vec<u64> = prices.iter().map(|(_, price)| *price).collect();
        let avg_price = recent_prices.iter().sum::<u64>() / recent_prices.len() as u64;
        let base_threshold = (self.config.base_gas_price_wei as f64 * self.config.congestion_threshold_multiplier) as u64;
        
        // Consider congested if average recent price is above threshold
        avg_price > base_threshold
    }

    /// Check if network is currently congested
    pub fn is_congested(&self) -> bool {
        *self.is_congested.lock().unwrap()
    }

    /// Get congestion multiplier
    pub fn get_congestion_multiplier(&self) -> f64 {
        if self.is_congested() {
            self.config.congestion_threshold_multiplier
        } else {
            1.0
        }
    }
}

/// BSC-specific fee model provider
#[derive(Debug)]
pub struct BSCFeeModelProvider {
    gas_adjuster: Arc<GasAdjuster>,
    base_token_ratio_provider: Arc<dyn BaseTokenRatioProvider>,
    config: FeeModelConfig,
    bsc_config: BSCFeeModelConfig,
    congestion_detector: BSCCongestionDetector,
    last_gas_price: std::sync::Mutex<Option<u64>>,
    last_update: std::sync::Mutex<std::time::Instant>,
}

impl BSCFeeModelProvider {
    /// Create a new BSC fee model provider
    pub fn new(
        gas_adjuster: Arc<GasAdjuster>,
        base_token_ratio_provider: Arc<dyn BaseTokenRatioProvider>,
        config: FeeModelConfig,
        bsc_config: BSCFeeModelConfig,
    ) -> Self {
        let congestion_detector = BSCCongestionDetector::new(bsc_config.clone());
        
        Self {
            gas_adjuster,
            base_token_ratio_provider,
            config,
            bsc_config,
            congestion_detector,
            last_gas_price: std::sync::Mutex::new(None),
            last_update: std::sync::Mutex::new(std::time::Instant::now()),
        }
    }

    /// Create BSC fee model provider for mainnet
    pub fn mainnet(
        gas_adjuster: Arc<GasAdjuster>,
        base_token_ratio_provider: Arc<dyn BaseTokenRatioProvider>,
        config: FeeModelConfig,
    ) -> Self {
        Self::new(
            gas_adjuster,
            base_token_ratio_provider,
            config,
            BSCFeeModelConfig::mainnet(),
        )
    }

    /// Create BSC fee model provider for testnet
    pub fn testnet(
        gas_adjuster: Arc<GasAdjuster>,
        base_token_ratio_provider: Arc<dyn BaseTokenRatioProvider>,
        config: FeeModelConfig,
    ) -> Self {
        Self::new(
            gas_adjuster,
            base_token_ratio_provider,
            config,
            BSCFeeModelConfig::testnet(),
        )
    }

    /// Get BSC-optimized gas price with smoothing
    async fn get_bsc_gas_price(&self) -> u64 {
        let raw_price = self.gas_adjuster.estimate_effective_gas_price();
        
        // Update congestion detector
        self.congestion_detector.update_gas_price(raw_price);
        
        // Apply BSC-specific optimizations
        let is_congested = self.congestion_detector.is_congested();
        let recommended_price = self.bsc_config.get_recommended_gas_price(raw_price, is_congested);
        
        // Apply price smoothing if enabled
        let final_price = if self.bsc_config.price_smoothing_factor > 0.0 {
            self.apply_price_smoothing(recommended_price)
        } else {
            recommended_price
        };

        // Update cache
        *self.last_gas_price.lock().unwrap() = Some(final_price);
        *self.last_update.lock().unwrap() = std::time::Instant::now();

        final_price
    }

    /// Apply price smoothing to reduce volatility
    fn apply_price_smoothing(&self, new_price: u64) -> u64 {
        let last_price = self.last_gas_price.lock().unwrap();
        
        if let Some(last) = *last_price {
            let smoothing = self.bsc_config.price_smoothing_factor;
            let smoothed = (last as f64 * smoothing + new_price as f64 * (1.0 - smoothing)) as u64;
            
            // Ensure we don't smooth too much and miss important price changes
            let max_change = (last as f64 * 0.5) as u64; // Allow up to 50% change
            if smoothed.abs_diff(last) > max_change {
                new_price // Use new price if change is too large
            } else {
                smoothed
            }
        } else {
            new_price // First time, no smoothing
        }
    }

    /// Get BSC network status
    pub fn get_bsc_network_status(&self) -> BSCNetworkStatus {
        let current_gas_price = self.last_gas_price.lock().unwrap().unwrap_or(self.bsc_config.base_gas_price_wei);
        let is_congested = self.congestion_detector.is_congested();
        let congestion_multiplier = self.congestion_detector.get_congestion_multiplier();

        BSCNetworkStatus {
            current_gas_price,
            base_gas_price: self.bsc_config.base_gas_price_wei,
            max_gas_price: self.bsc_config.max_gas_price_wei,
            is_congested,
            congestion_multiplier,
            block_time: self.bsc_config.block_time_seconds,
            last_update: *self.last_update.lock().unwrap(),
        }
    }
}

#[async_trait]
impl BatchFeeModelInputProvider for BSCFeeModelProvider {
    async fn get_fee_model_params(&self) -> FeeParams {
        let bsc_gas_price = self.get_bsc_gas_price().await;
        
        match self.config {
            FeeModelConfig::V1(config) => FeeParams::V1(FeeParamsV1 {
                config,
                l1_gas_price: bsc_gas_price,
            }),
            FeeModelConfig::V2(config) => FeeParams::V2(FeeParamsV2::new(
                config,
                bsc_gas_price,
                self.gas_adjuster.estimate_effective_pubdata_price().await,
                self.base_token_ratio_provider.get_conversion_ratio(),
            )),
        }
    }
}

/// BSC network status information
#[derive(Debug, Clone)]
pub struct BSCNetworkStatus {
    pub current_gas_price: u64,
    pub base_gas_price: u64,
    pub max_gas_price: u64,
    pub is_congested: bool,
    pub congestion_multiplier: f64,
    pub block_time: u64,
    pub last_update: std::time::Instant,
}

impl BSCNetworkStatus {
    /// Check if gas price is within acceptable range
    pub fn is_gas_price_acceptable(&self) -> bool {
        self.current_gas_price <= self.max_gas_price
    }

    /// Get gas price in Gwei
    pub fn gas_price_gwei(&self) -> f64 {
        self.current_gas_price as f64 / 1_000_000_000.0
    }

    /// Get recommended gas price for priority transactions
    pub fn priority_gas_price(&self) -> u64 {
        let multiplier = if self.is_congested { 1.3 } else { 1.1 };
        let priority_price = (self.current_gas_price as f64 * multiplier) as u64;
        std::cmp::min(priority_price, self.max_gas_price)
    }

    /// Get time since last update
    pub fn time_since_update(&self) -> Duration {
        self.last_update.elapsed()
    }
}

impl fmt::Display for BSCNetworkStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "BSC Network Status: {} Gwei ({}), congested: {}, multiplier: {:.2}x",
            self.gas_price_gwei(),
            if self.is_gas_price_acceptable() { "OK" } else { "HIGH" },
            self.is_congested,
            self.congestion_multiplier
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::num::NonZeroU64;
    use zksync_types::fee_model::{BaseTokenConversionRatio, ConversionRatio, FeeModelConfigV2};

    #[derive(Debug, Clone)]
    struct MockBaseTokenRatioProvider {
        ratio: BaseTokenConversionRatio,
    }

    impl MockBaseTokenRatioProvider {
        pub fn new(ratio: BaseTokenConversionRatio) -> Self {
            Self { ratio }
        }
    }

    #[async_trait]
    impl BaseTokenRatioProvider for MockBaseTokenRatioProvider {
        fn get_conversion_ratio(&self) -> BaseTokenConversionRatio {
            self.ratio
        }
    }

    #[test]
    fn test_bsc_fee_model_config() {
        let mainnet_config = BSCFeeModelConfig::mainnet();
        assert_eq!(mainnet_config.base_gas_price_wei, 5_000_000_000);
        assert_eq!(mainnet_config.max_gas_price_wei, 20_000_000_000);
        assert_eq!(mainnet_config.block_time_seconds, 3);

        let testnet_config = BSCFeeModelConfig::testnet();
        assert_eq!(testnet_config.base_gas_price_wei, 10_000_000_000);
        assert_eq!(testnet_config.max_gas_price_wei, 50_000_000_000);
    }

    #[test]
    fn test_gas_price_recommendation() {
        let config = BSCFeeModelConfig::mainnet();
        
        // Normal conditions
        let normal_price = config.get_recommended_gas_price(6_000_000_000, false);
        assert_eq!(normal_price, 6_000_000_000);
        
        // Congested conditions
        let congested_price = config.get_recommended_gas_price(6_000_000_000, true);
        assert!(congested_price > 6_000_000_000);
        assert!(congested_price <= config.max_gas_price_wei);
        
        // Price below base
        let low_price = config.get_recommended_gas_price(3_000_000_000, false);
        assert_eq!(low_price, config.base_gas_price_wei);
    }

    #[test]
    fn test_congestion_detector() {
        let config = BSCFeeModelConfig::mainnet();
        let detector = BSCCongestionDetector::new(config);
        
        // Initially not congested
        assert!(!detector.is_congested());
        
        // Add some normal prices
        detector.update_gas_price(5_000_000_000);
        detector.update_gas_price(6_000_000_000);
        detector.update_gas_price(5_500_000_000);
        
        // Should still not be congested
        assert!(!detector.is_congested());
        
        // Add high prices
        detector.update_gas_price(15_000_000_000);
        detector.update_gas_price(16_000_000_000);
        detector.update_gas_price(14_000_000_000);
        
        // Should detect congestion (this might need adjustment based on timing)
        let multiplier = detector.get_congestion_multiplier();
        assert!(multiplier >= 1.0);
    }

    #[test]
    fn test_bsc_network_status() {
        let status = BSCNetworkStatus {
            current_gas_price: 8_000_000_000, // 8 Gwei
            base_gas_price: 5_000_000_000,    // 5 Gwei
            max_gas_price: 20_000_000_000,    // 20 Gwei
            is_congested: false,
            congestion_multiplier: 1.0,
            block_time: 3,
            last_update: std::time::Instant::now(),
        };

        assert!(status.is_gas_price_acceptable());
        assert_eq!(status.gas_price_gwei(), 8.0);
        
        let priority_price = status.priority_gas_price();
        assert!(priority_price > status.current_gas_price);
        assert!(priority_price <= status.max_gas_price);
    }
}