//! BSC 费用优化配置
//! 
//! 专门为 BSC 网络设计的费用计算配置和策略

use serde::{Deserialize, Serialize};

/// BSC 费用优化配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscFeeOptimizationConfig {
    /// 是否启用 BSC 费用优化
    pub enabled: bool,
    
    /// 基础费用配置
    pub base_fee_config: BscBaseFeeConfig,
    
    /// 优先费用配置
    pub priority_fee_config: BscPriorityFeeConfig,
    
    /// 网络拥堵检测配置
    pub congestion_config: BscCongestionConfig,
    
    /// 重发策略配置
    pub resend_config: BscResendConfig,
}

/// BSC 基础费用配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscBaseFeeConfig {
    /// 最小基础费用 (wei)
    pub min_base_fee: u64,
    
    /// 最大基础费用 (wei)
    pub max_base_fee: u64,
    
    /// 目标基础费用 (wei)
    pub target_base_fee: u64,
    
    /// 安全边距百分比 (仅在网络拥堵时应用)
    pub safety_margin_percent: u64,
}

/// BSC 优先费用配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscPriorityFeeConfig {
    /// 最小优先费用 (wei)
    pub min_priority_fee: u64,
    
    /// 最大优先费用 (wei)
    pub max_priority_fee: u64,
    
    /// 快速确认优先费用 (wei)
    pub fast_priority_fee: u64,
}

/// BSC 网络拥堵检测配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscCongestionConfig {
    /// 拥堵检测阈值 (wei)
    pub congestion_threshold: u64,
    
    /// 拥堵时费用提升百分比
    pub congestion_boost_percent: u64,
    
    /// 网络状况评估窗口 (区块数)
    pub assessment_window_blocks: u32,
}

/// BSC 重发策略配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscResendConfig {
    /// 重发时费用提升倍数
    pub price_bump_multiplier: u64,
    
    /// 时间衰减费用提升百分比 (每个区块)
    pub time_decay_boost_percent: f64,
    
    /// 最大重发次数
    pub max_resend_attempts: u32,
}

impl Default for BscFeeOptimizationConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            base_fee_config: BscBaseFeeConfig {
                min_base_fee: 100_000_000u64,      // 0.1 Gwei
                max_base_fee: 5_000_000_000u64,    // 5 Gwei
                target_base_fee: 1_000_000_000u64, // 1 Gwei
                safety_margin_percent: 10,         // 10%
            },
            priority_fee_config: BscPriorityFeeConfig {
                min_priority_fee: 100_000_000u64,  // 0.1 Gwei
                max_priority_fee: 2_000_000_000u64, // 2 Gwei
                fast_priority_fee: 500_000_000u64, // 0.5 Gwei
            },
            congestion_config: BscCongestionConfig {
                congestion_threshold: 3_000_000_000u64, // 3 Gwei
                congestion_boost_percent: 50,           // 50%
                assessment_window_blocks: 10,           // 10 blocks (~30 seconds)
            },
            resend_config: BscResendConfig {
                price_bump_multiplier: 2,    // 100% increase
                time_decay_boost_percent: 15.0, // 15% per block
                max_resend_attempts: 5,      // 最多重发 5 次
            },
        }
    }
}

impl BscFeeOptimizationConfig {
    /// 从环境变量加载配置
    pub fn from_env() -> Self {
        let mut config = Self::default();
        
        // 基础费用配置
        if let Ok(min_fee) = std::env::var("BSC_MIN_BASE_FEE") {
            if let Ok(fee) = min_fee.parse::<u64>() {
                config.base_fee_config.min_base_fee = fee;
            }
        }
        
        if let Ok(max_fee) = std::env::var("BSC_MAX_BASE_FEE") {
            if let Ok(fee) = max_fee.parse::<u64>() {
                config.base_fee_config.max_base_fee = fee;
            }
        }
        
        if let Ok(target_fee) = std::env::var("BSC_TARGET_BASE_FEE") {
            if let Ok(fee) = target_fee.parse::<u64>() {
                config.base_fee_config.target_base_fee = fee;
            }
        }
        
        // 优先费用配置
        if let Ok(fast_fee) = std::env::var("BSC_FAST_PRIORITY_FEE") {
            if let Ok(fee) = fast_fee.parse::<u64>() {
                config.priority_fee_config.fast_priority_fee = fee;
            }
        }
        
        // 拥堵检测配置
        if let Ok(threshold) = std::env::var("BSC_CONGESTION_THRESHOLD") {
            if let Ok(fee) = threshold.parse::<u64>() {
                config.congestion_config.congestion_threshold = fee;
            }
        }
        
        // 启用/禁用优化
        if let Ok(enabled) = std::env::var("BSC_FEE_OPTIMIZATION_ENABLED") {
            config.enabled = enabled.to_lowercase() == "true";
        }
        
        config
    }
    
    /// 验证配置的合理性
    pub fn validate(&self) -> Result<(), String> {
        // 检查基础费用配置
        if self.base_fee_config.min_base_fee >= self.base_fee_config.max_base_fee {
            return Err("min_base_fee must be less than max_base_fee".to_string());
        }
        
        if self.base_fee_config.target_base_fee < self.base_fee_config.min_base_fee 
            || self.base_fee_config.target_base_fee > self.base_fee_config.max_base_fee {
            return Err("target_base_fee must be between min_base_fee and max_base_fee".to_string());
        }
        
        // 检查优先费用配置
        if self.priority_fee_config.min_priority_fee >= self.priority_fee_config.max_priority_fee {
            return Err("min_priority_fee must be less than max_priority_fee".to_string());
        }
        
        // 检查拥堵配置
        if self.congestion_config.congestion_threshold <= self.base_fee_config.target_base_fee {
            return Err("congestion_threshold should be higher than target_base_fee".to_string());
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config_validation() {
        let config = BscFeeOptimizationConfig::default();
        assert!(config.validate().is_ok());
    }

    #[test]
    fn test_config_from_env() {
        std::env::set_var("BSC_MIN_BASE_FEE", "200000000");
        std::env::set_var("BSC_TARGET_BASE_FEE", "1500000000");
        std::env::set_var("BSC_FEE_OPTIMIZATION_ENABLED", "true");
        
        let config = BscFeeOptimizationConfig::from_env();
        
        assert_eq!(config.base_fee_config.min_base_fee, 200_000_000);
        assert_eq!(config.base_fee_config.target_base_fee, 1_500_000_000);
        assert!(config.enabled);
        
        // 清理环境变量
        std::env::remove_var("BSC_MIN_BASE_FEE");
        std::env::remove_var("BSC_TARGET_BASE_FEE");
        std::env::remove_var("BSC_FEE_OPTIMIZATION_ENABLED");
    }
}