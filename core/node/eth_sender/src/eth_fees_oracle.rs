use std::{
    cmp::{max, min},
    fmt,
    sync::Arc,
};

use zksync_eth_client::{ClientError, EnrichedClientError};
use zksync_node_fee_model::l1_gas_price::TxParamsProvider;
use tokio::runtime::Handle;
use zksync_types::eth_sender::TxHistory;

use crate::{abstract_l1_interface::OperatorType, EthSenderError};

#[derive(Debug)]
pub(crate) struct EthFees {
    pub(crate) base_fee_per_gas: u64,
    pub(crate) priority_fee_per_gas: u64,
    pub(crate) blob_base_fee_per_gas: Option<u64>,
    pub(crate) max_gas_per_pubdata_price: Option<u64>,
}

pub(crate) trait EthFeesOracle: 'static + Sync + Send + fmt::Debug {
    fn calculate_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
        operator_type: OperatorType,
    ) -> Result<EthFees, EthSenderError>;
}

/// 网络类型检测
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum NetworkType {
    Ethereum,
    Bsc,
    Other,
}

/// 根据链 ID 检测网络类型
fn detect_network_type_from_env() -> NetworkType {
    if let Ok(chain_id_str) = std::env::var("L1_CHAIN_ID") {
        if let Ok(chain_id) = chain_id_str.parse::<u64>() {
            match chain_id {
                1 | 5 | 11155111 => NetworkType::Ethereum,
                56 | 97 => NetworkType::Bsc,
                _ => NetworkType::Other,
            }
        } else {
            NetworkType::Ethereum // 默认
        }
    } else {
        NetworkType::Ethereum // 默认
    }
}


/// BSC 优化的 Gas Price Provider
/// 专门为 BSC 网络设计的智能费用计算器
#[derive(Debug)]
pub struct BscGasPriceProvider {
    gas_adjuster: Arc<dyn TxParamsProvider>,
    safety_margin_percent: u64,
    /// BSC 网络的动态费用配置
    bsc_config: BscFeeConfig,
}

/// BSC 费用配置
#[derive(Debug, Clone)]
struct BscFeeConfig {
    /// 最小 gas 价格 (wei)
    min_gas_price: u64,
    /// 最大 gas 价格 (wei) 
    max_gas_price: u64,
    /// 目标 gas 价格 (wei)
    target_gas_price: u64,
    /// 快速确认的优先费用 (wei)
    fast_priority_fee: u64,
    /// 网络拥堵检测阈值
    congestion_threshold: u64,
}

impl Default for BscFeeConfig {
    fn default() -> Self {
        Self {
            min_gas_price: 100_000_000u64,      // 0.1 Gwei - BSC 最低费用
            max_gas_price: 5_000_000_000u64,    // 5 Gwei - BSC 优化上限
            target_gas_price: 1_000_000_000u64, // 1 Gwei - BSC 目标费用
            fast_priority_fee: 100_000_000u64,  // 0.1 Gwei - BSC最低要求的优先费用
            congestion_threshold: 3_000_000_000u64, // 3 Gwei - 拥堵阈值
        }
    }
}

impl BscGasPriceProvider {
    pub fn new(gas_adjuster: Arc<dyn TxParamsProvider>) -> Self {
        Self {
            gas_adjuster,
            safety_margin_percent: 10, // BSC 优化: 降低到 10% 安全边距
            bsc_config: BscFeeConfig::default(),
        }
    }

    /// BSC 优化: 智能 gas 价格计算
    /// 根据网络状况动态调整，确保快速确认和成本效益
    pub async fn get_optimized_gas_price(&self) -> BscGasResult {
        // 1. 尝试获取实时网络费用
        let network_base_fee = self.gas_adjuster.get_base_fee(0);
        let _network_priority_fee = self.gas_adjuster.get_priority_fee();
        
        // 2. 计算基础费用
        let base_gas_price = if network_base_fee > 0 {
            // 使用网络实际费用
            network_base_fee
        } else {
            // 网络异常时使用 BSC 目标费用
            self.bsc_config.target_gas_price
        };

        // 3. BSC 网络状况评估
        let network_status = self.assess_network_congestion(base_gas_price);
        
        // 4. 根据网络状况调整费用策略
        let (optimized_base_fee, optimized_priority_fee) = match network_status {
            BscNetworkStatus::Low => {
                // 网络空闲: 使用最低费用，但确保满足BSC最低要求
                (self.bsc_config.min_gas_price, self.bsc_config.fast_priority_fee)
            },
            BscNetworkStatus::Normal => {
                // 网络正常: 使用目标费用
                (self.bsc_config.target_gas_price, self.bsc_config.fast_priority_fee)
            },
            BscNetworkStatus::Congested => {
                // 网络拥堵: 使用提升费用但不超过上限
                let boosted_fee = (base_gas_price * 150) / 100; // 50% 提升
                let capped_fee = boosted_fee.min(self.bsc_config.max_gas_price);
                (capped_fee, self.bsc_config.fast_priority_fee * 2)
            },
        };

        // 5. 应用安全边距 (BSC 优化: 仅在必要时)
        let final_base_fee = if network_status == BscNetworkStatus::Congested {
            // 拥堵时增加安全边距
            (optimized_base_fee * (100 + self.safety_margin_percent)) / 100
        } else {
            // 正常情况下不增加边距，保持成本效益
            optimized_base_fee
        };

        let result = BscGasResult {
            base_fee: final_base_fee,
            priority_fee: optimized_priority_fee,
            network_status,
            is_optimized: true,
        };

        tracing::info!(
            "BSC optimized gas calculation: network_base={} wei, final_base={} wei ({} Gwei), priority={} wei ({} Gwei), status={:?}",
            network_base_fee,
            result.base_fee,
            result.base_fee / 1_000_000_000,
            result.priority_fee,
            result.priority_fee / 1_000_000_000,
            result.network_status
        );

        result
    }

    /// 评估 BSC 网络拥堵状况
    fn assess_network_congestion(&self, current_base_fee: u64) -> BscNetworkStatus {
        if current_base_fee <= self.bsc_config.target_gas_price {
            BscNetworkStatus::Low
        } else if current_base_fee <= self.bsc_config.congestion_threshold {
            BscNetworkStatus::Normal  
        } else {
            BscNetworkStatus::Congested
        }
    }

    /// 兼容性方法: 保持向后兼容
    #[allow(dead_code)]
    pub async fn get_gas_price_with_margin(&self) -> u64 {
        let result = self.get_optimized_gas_price().await;
        result.base_fee
    }
}

/// BSC 网络状况
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum BscNetworkStatus {
    Low,        // 网络空闲
    Normal,     // 网络正常
    Congested,  // 网络拥堵
}

/// BSC Gas 计算结果
#[derive(Debug)]
pub(crate) struct BscGasResult {
    base_fee: u64,
    priority_fee: u64,
    network_status: BscNetworkStatus,
    #[allow(dead_code)]
    is_optimized: bool,
}

#[derive(Debug)]
pub(crate) struct GasAdjusterFeesOracle {
    pub gas_adjuster: Arc<dyn TxParamsProvider>,
    pub max_acceptable_priority_fee_in_gwei: u64,
    pub time_in_mempool_in_l1_blocks_cap: u32,
    pub max_acceptable_base_fee_in_wei: u64,
    pub bsc_provider: BscGasPriceProvider,
}

impl GasAdjusterFeesOracle {
    /// 网络感知的费用检查 - 支持 BSC 动态 gas price (含 20% 安全边距)

    /// BSC 优化: 智能费用检查和回退策略
    /// 支持网络感知的动态 gas price 计算
    fn assert_fee_is_not_zero(&self, value: u64, fee_type: &'static str) -> u64 {
        if value == 0 {
            let network_type = detect_network_type_from_env();
            match network_type {
                NetworkType::Ethereum => {
                    // 以太坊：保持原有严格行为
                    panic!(
                        "L1 RPC incorrectly reported {fee_type} prices, either it doesn't return them at \
                        all or returns 0's, eth-sender cannot continue without proper {fee_type} prices!"
                    );
                }
                NetworkType::Bsc => {
                    // BSC 优化：使用智能费用计算
                    match fee_type {
                        "base" => {
                            let gas_result = tokio::task::block_in_place(|| {
                                Handle::current().block_on(
                                    self.bsc_provider.get_optimized_gas_price()
                                )
                            });

                            tracing::info!(
                                "BSC optimized fee calculation: base={} wei ({} Gwei), priority={} wei ({} Gwei), status={:?}",
                                gas_result.base_fee,
                                gas_result.base_fee / 1_000_000_000,
                                gas_result.priority_fee,
                                gas_result.priority_fee / 1_000_000_000,
                                gas_result.network_status
                            );
                            gas_result.base_fee
                        }
                        "priority" => {
                            let gas_result = tokio::task::block_in_place(|| {
                                Handle::current().block_on(
                                    self.bsc_provider.get_optimized_gas_price()
                                )
                            });
                            gas_result.priority_fee
                        }
                        "blob" => {
                            // BSC 不使用 blob，返回最小值
                            let blob_fee = 100_000_000u64; // 0.1 Gwei
                            tracing::debug!("BSC blob fee (not used): {} wei", blob_fee);
                            blob_fee
                        }
                        _ => {
                            // 未知费用类型，使用 BSC 目标费用
                            let default_fee = 1_000_000_000u64; // 1 Gwei - BSC 目标费用
                            tracing::warn!("BSC unknown fee type '{}', using BSC target fee: {} wei ({} Gwei)", 
                                fee_type, default_fee, default_fee / 1_000_000_000);
                            default_fee
                        }
                    }
                }
                NetworkType::Other => {
                    // 其他网络：使用保守默认值
                    let default_value = match fee_type {
                        "base" => 5_000_000_000u64,  // 5 Gwei - 适中的默认值
                        "priority" => 1_000_000_000u64, // 1 Gwei - 适中的优先费用
                        "blob" => 1_000_000_000u64,  // 1 Gwei
                        _ => 5_000_000_000u64,
                    };
                    tracing::warn!(
                        "Non-Ethereum network detected: using default {} fee: {} wei ({} Gwei)",
                        fee_type, default_value, default_value / 1_000_000_000
                    );
                    default_value
                }
            }
        } else {
            value
        }
    }

    /// BSC 优化: 智能优先费用检查
    /// 根据网络类型采用不同的费用验证策略
    fn check_priority_fee(&self, priority_fee_per_gas: u64) -> u64 {
        if priority_fee_per_gas > self.max_acceptable_priority_fee_in_gwei {
            let network_type = detect_network_type_from_env();
            match network_type {
                NetworkType::Ethereum => {
                    // 以太坊：保持原有严格行为
                    panic!(
                        "Extremely high value of priority_fee_per_gas is suggested: {}, while max acceptable is {}",
                        priority_fee_per_gas,
                        self.max_acceptable_priority_fee_in_gwei
                    );
                }
                NetworkType::Bsc => {
                    // BSC 优化：智能费用调整
                    let bsc_result = tokio::task::block_in_place(|| {
                        Handle::current().block_on(
                            self.bsc_provider.get_optimized_gas_price()
                        )
                    });
                    
                    // 使用 BSC 优化的优先费用，但不超过配置上限
                    let optimized_priority_fee = bsc_result.priority_fee.min(self.max_acceptable_priority_fee_in_gwei);
                    
                    tracing::info!(
                        "BSC priority fee optimization: suggested={} wei, optimized={} wei, max_acceptable={} wei",
                        priority_fee_per_gas,
                        optimized_priority_fee,
                        self.max_acceptable_priority_fee_in_gwei
                    );
                    
                    return optimized_priority_fee;
                }
                NetworkType::Other => {
                    // 其他网络：优雅处理，使用适中的费用
                    let capped_fee = self.max_acceptable_priority_fee_in_gwei.min(2_000_000_000u64); // 最多 2 Gwei
                    tracing::warn!(
                        "Other network: High priority fee {} detected, using capped fee: {} wei ({} Gwei)",
                        priority_fee_per_gas,
                        capped_fee,
                        capped_fee / 1_000_000_000
                    );
                    return capped_fee;
                }
            }
        }
        priority_fee_per_gas
    }

    fn is_base_fee_exceeding_limit(&self, value: u64) -> bool {
        if value > self.max_acceptable_base_fee_in_wei {
            tracing::warn!(
                    "base fee per gas: {} exceed max acceptable fee in configuration: {}, skip transaction",
                    value,
                    self.max_acceptable_base_fee_in_wei
            );
            return true;
        }
        false
    }

    /// BSC 优化: 专门的 BSC 费用计算方法
    /// 使用简化的费用模型，针对 BSC 网络特性优化
    fn calculate_bsc_optimized_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
    ) -> Result<EthFees, EthSenderError> {
        // 获取 BSC 优化的费用
        let bsc_result = tokio::task::block_in_place(|| {
            Handle::current().block_on(
                self.bsc_provider.get_optimized_gas_price()
            )
        });

        let mut base_fee_per_gas = bsc_result.base_fee;
        let mut priority_fee_per_gas = bsc_result.priority_fee;

        // BSC 重发策略: 更激进的费用提升
        if let Some(previous_tx) = previous_sent_tx {
            const BSC_PRICE_BUMP_MULTIPLIER: u64 = 2; // BSC: 100% 提升确保快速确认
            
            base_fee_per_gas = base_fee_per_gas.max(
                previous_tx.base_fee_per_gas * BSC_PRICE_BUMP_MULTIPLIER
            );
            priority_fee_per_gas = priority_fee_per_gas.max(
                previous_tx.priority_fee_per_gas * BSC_PRICE_BUMP_MULTIPLIER
            );

            tracing::info!(
                "BSC fee bump for resend: tx_id={}, prev_base={} wei, new_base={} wei, prev_priority={} wei, new_priority={} wei",
                previous_tx.id,
                previous_tx.base_fee_per_gas,
                base_fee_per_gas,
                previous_tx.priority_fee_per_gas,
                priority_fee_per_gas
            );
        }

        // BSC 时间衰减: 根据在内存池中的时间调整费用
        if time_in_mempool_in_l1_blocks > 0 {
            // BSC 3秒出块，更快的费用提升策略
            let time_multiplier = 1.0 + (time_in_mempool_in_l1_blocks as f64 * 0.15); // 每个区块增加 15%
            base_fee_per_gas = (base_fee_per_gas as f64 * time_multiplier) as u64;
            priority_fee_per_gas = (priority_fee_per_gas as f64 * time_multiplier) as u64;

            tracing::debug!(
                "BSC time-based fee adjustment: blocks_in_mempool={}, multiplier={:.2}, adjusted_base={} wei, adjusted_priority={} wei",
                time_in_mempool_in_l1_blocks,
                time_multiplier,
                base_fee_per_gas,
                priority_fee_per_gas
            );
        }

        // 应用费用限制检查
        if self.is_base_fee_exceeding_limit(base_fee_per_gas) {
            return Err(EthSenderError::ExceedMaxBaseFee);
        }

        priority_fee_per_gas = self.check_priority_fee(priority_fee_per_gas);

        tracing::info!(
            "BSC optimized fees calculated: base={} wei ({} Gwei), priority={} wei ({} Gwei), network_status={:?}",
            base_fee_per_gas,
            base_fee_per_gas / 1_000_000_000,
            priority_fee_per_gas,
            priority_fee_per_gas / 1_000_000_000,
            bsc_result.network_status
        );

        Ok(EthFees {
            base_fee_per_gas,
            priority_fee_per_gas,
            blob_base_fee_per_gas: None, // BSC 不支持 blob
            max_gas_per_pubdata_price: None,
        })
    }

    fn calculate_fees_with_blob_sidecar(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
    ) -> Result<EthFees, EthSenderError> {
        const MIN_PRICE_BUMP_MULTIPLIER: f64 = 2.00;
        const MIN_PRICE_BUMP_MULTIPLIER_U64: u64 = 2;

        let capped_time_in_mempool_in_l1_blocks = min(
            time_in_mempool_in_l1_blocks,
            self.time_in_mempool_in_l1_blocks_cap,
        );

        let mut base_fee_per_gas = self
            .gas_adjuster
            .get_blob_tx_base_fee(capped_time_in_mempool_in_l1_blocks);
        base_fee_per_gas = self.assert_fee_is_not_zero(base_fee_per_gas, "base");
        if self.is_base_fee_exceeding_limit(base_fee_per_gas) {
            return Err(EthSenderError::ExceedMaxBaseFee);
        }
        let mut blob_base_fee_per_gas = self
            .gas_adjuster
            .get_blob_tx_blob_base_fee(capped_time_in_mempool_in_l1_blocks);
        blob_base_fee_per_gas = self.assert_fee_is_not_zero(blob_base_fee_per_gas, "blob");

        let mut priority_fee_per_gas = self.gas_adjuster.get_blob_tx_priority_fee();
        if let Some(previous_sent_tx) = previous_sent_tx {
            let blob_result = self.verify_base_fee_not_too_low_on_resend(
                previous_sent_tx.id,
                previous_sent_tx.blob_base_fee_per_gas.unwrap_or(0),
                blob_base_fee_per_gas,
                self.gas_adjuster.get_next_block_minimal_blob_base_fee(),
                MIN_PRICE_BUMP_MULTIPLIER,
                "blob_base_fee_per_gas",
            );

            let base_result = self.verify_base_fee_not_too_low_on_resend(
                previous_sent_tx.id,
                previous_sent_tx.base_fee_per_gas,
                base_fee_per_gas,
                self.gas_adjuster.get_next_block_minimal_base_fee(),
                MIN_PRICE_BUMP_MULTIPLIER,
                "base_fee_per_gas",
            );

            match (blob_result, base_result) {
                (Ok(_), Ok(_)) => {}
                (Err(err), Err(_)) => return Err(err),
                (Ok(_), Err(_)) => {
                    base_fee_per_gas =
                        previous_sent_tx.base_fee_per_gas * MIN_PRICE_BUMP_MULTIPLIER_U64;
                }
                (Err(_), Ok(_)) => {
                    blob_base_fee_per_gas = previous_sent_tx.blob_base_fee_per_gas.unwrap()
                        * MIN_PRICE_BUMP_MULTIPLIER_U64;
                }
            }

            priority_fee_per_gas = max(
                priority_fee_per_gas,
                previous_sent_tx.priority_fee_per_gas * MIN_PRICE_BUMP_MULTIPLIER_U64,
            );
        }

        priority_fee_per_gas = self.check_priority_fee(priority_fee_per_gas);

        Ok(EthFees {
            base_fee_per_gas,
            priority_fee_per_gas,
            blob_base_fee_per_gas: Some(blob_base_fee_per_gas),
            max_gas_per_pubdata_price: None,
        })
    }

    fn calculate_fees_no_blob_sidecar(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
    ) -> Result<EthFees, EthSenderError> {
        const MIN_PRICE_BUMP_MULTIPLIER: f64 = 1.10;

        let capped_time_in_mempool_in_l1_blocks = min(
            time_in_mempool_in_l1_blocks,
            self.time_in_mempool_in_l1_blocks_cap,
        );
        let base_fee_per_gas = self
            .gas_adjuster
            .get_base_fee(capped_time_in_mempool_in_l1_blocks);
        let base_fee_per_gas = self.assert_fee_is_not_zero(base_fee_per_gas, "base");
        if self.is_base_fee_exceeding_limit(base_fee_per_gas) {
            return Err(EthSenderError::ExceedMaxBaseFee);
        }

        let mut priority_fee_per_gas = self.gas_adjuster.get_priority_fee();

        if let Some(previous_sent_tx) = previous_sent_tx {
            self.verify_base_fee_not_too_low_on_resend(
                previous_sent_tx.id,
                previous_sent_tx.base_fee_per_gas,
                base_fee_per_gas,
                self.gas_adjuster.get_next_block_minimal_base_fee(),
                MIN_PRICE_BUMP_MULTIPLIER,
                "base_fee_per_gas",
            )?;

            priority_fee_per_gas = max(
                priority_fee_per_gas,
                (previous_sent_tx.priority_fee_per_gas as f64 * MIN_PRICE_BUMP_MULTIPLIER).ceil()
                    as u64,
            );
        }

        priority_fee_per_gas = self.check_priority_fee(priority_fee_per_gas);

        Ok(EthFees {
            base_fee_per_gas,
            blob_base_fee_per_gas: None,
            priority_fee_per_gas,
            max_gas_per_pubdata_price: None,
        })
    }

    fn calculate_fees_for_gateway_tx(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
    ) -> Result<EthFees, EthSenderError> {
        const MIN_PRICE_BUMP_MULTIPLIER: f64 = 1.10;

        let capped_time_in_mempool_in_l1_blocks = min(
            time_in_mempool_in_l1_blocks,
            self.time_in_mempool_in_l1_blocks_cap,
        );
        let base_fee_per_gas = self
            .gas_adjuster
            .gateway_get_base_fee(capped_time_in_mempool_in_l1_blocks);
        let base_fee_per_gas = self.assert_fee_is_not_zero(base_fee_per_gas, "base");
        if self.is_base_fee_exceeding_limit(base_fee_per_gas) {
            return Err(EthSenderError::ExceedMaxBaseFee);
        }

        let mut gas_per_pubdata = self
            .gas_adjuster
            .get_gateway_price_per_pubdata(capped_time_in_mempool_in_l1_blocks);

        if let Some(previous_sent_tx) = previous_sent_tx {
            self.verify_base_fee_not_too_low_on_resend(
                previous_sent_tx.id,
                previous_sent_tx.base_fee_per_gas,
                base_fee_per_gas,
                self.gas_adjuster.get_next_block_minimal_base_fee(),
                MIN_PRICE_BUMP_MULTIPLIER,
                "base_fee_per_gas",
            )?;

            gas_per_pubdata =
                if let Some(prev_gas_per_pubdata) = previous_sent_tx.max_gas_per_pubdata {
                    max(
                        gas_per_pubdata,
                        (prev_gas_per_pubdata as f64 * MIN_PRICE_BUMP_MULTIPLIER).ceil() as u64,
                    )
                } else {
                    gas_per_pubdata
                };
        }

        Ok(EthFees {
            base_fee_per_gas,
            blob_base_fee_per_gas: None,
            priority_fee_per_gas: 0,
            max_gas_per_pubdata_price: Some(gas_per_pubdata),
        })
    }

    fn verify_base_fee_not_too_low_on_resend(
        &self,
        tx_id: u32,
        previous_fee: u64,
        fee_to_use: u64,
        next_block_minimal_fee: u64,
        min_price_bump_multiplier: f64,
        fee_type: &str,
    ) -> Result<(), EthSenderError> {
        let fee_to_use = fee_to_use as f64;
        if fee_to_use < (next_block_minimal_fee as f64)
            || fee_to_use < (previous_fee as f64 * min_price_bump_multiplier).ceil()
        {
            tracing::info!(
                "{fee_type} too low for resend detected for tx {}, \
                 suggested fee {:?}, \
                 previous_fee {:?}, \
                 next_block_minimal_fee {:?}, \
                 min_price_bump_multiplier {:?}",
                tx_id,
                fee_to_use,
                previous_fee,
                next_block_minimal_fee,
                min_price_bump_multiplier
            );
            let err = ClientError::Custom(format!("{fee_type} is too low"));
            let err = EnrichedClientError::new(err, "verify_base_fee_not_too_low_on_resend")
                .with_arg("fee_to_use", &fee_to_use)
                .with_arg("previous_fee", &previous_fee)
                .with_arg("next_block_minimal_fee", &next_block_minimal_fee)
                .with_arg("min_price_bump_multiplier", &min_price_bump_multiplier);
            return Err(err.into());
        }
        Ok(())
    }
}

impl EthFeesOracle for GasAdjusterFeesOracle {
    /// BSC 优化: 网络感知的费用计算
    /// 根据网络类型和操作类型选择最优的费用计算策略
    fn calculate_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
        operator_type: OperatorType,
    ) -> Result<EthFees, EthSenderError> {
        let network_type = detect_network_type_from_env();
        
        // BSC 网络优化路径
        if network_type == NetworkType::Bsc {
            tracing::debug!("Using BSC optimized fee calculation for operator_type={:?}", operator_type);
            
            match operator_type {
                OperatorType::NonBlob | OperatorType::Blob => {
                    // BSC 不支持 blob，统一使用优化的费用计算
                    return self.calculate_bsc_optimized_fees(previous_sent_tx, time_in_mempool_in_l1_blocks);
                }
                OperatorType::Gateway => {
                    // Gateway 交易使用特殊处理，但应用 BSC 优化
                    let mut result = self.calculate_fees_for_gateway_tx(previous_sent_tx, time_in_mempool_in_l1_blocks)?;
                    
                    // 对 Gateway 交易应用 BSC 费用优化
                    let bsc_result = tokio::task::block_in_place(|| {
                        Handle::current().block_on(
                            self.bsc_provider.get_optimized_gas_price()
                        )
                    });
                    
                    // 使用 BSC 优化的基础费用，但保持 Gateway 特有的 pubdata 价格
                    result.base_fee_per_gas = bsc_result.base_fee;
                    
                    tracing::info!(
                        "BSC Gateway fee optimization: base_fee={} wei ({} Gwei), pubdata_price={:?}",
                        result.base_fee_per_gas,
                        result.base_fee_per_gas / 1_000_000_000,
                        result.max_gas_per_pubdata_price
                    );
                    
                    return Ok(result);
                }
            }
        }
        
        // 以太坊和其他网络使用原有逻辑
        tracing::debug!("Using standard fee calculation for network_type={:?}, operator_type={:?}", network_type, operator_type);
        
        match operator_type {
            OperatorType::NonBlob => {
                self.calculate_fees_no_blob_sidecar(previous_sent_tx, time_in_mempool_in_l1_blocks)
            }
            OperatorType::Blob => self
                .calculate_fees_with_blob_sidecar(previous_sent_tx, time_in_mempool_in_l1_blocks),
            OperatorType::Gateway => {
                self.calculate_fees_for_gateway_tx(previous_sent_tx, time_in_mempool_in_l1_blocks)
            }
        }
    }
}
