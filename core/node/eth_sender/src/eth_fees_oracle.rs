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


/// BSC Gas Price Provider with 20% safety margin
#[derive(Debug)]
pub struct BscGasPriceProvider {
    gas_adjuster: Arc<dyn TxParamsProvider>,
    safety_margin_percent: u64, // 安全边距百分比 (例如 20 表示 20%)
}

impl BscGasPriceProvider {
    pub fn new(gas_adjuster: Arc<dyn TxParamsProvider>) -> Self {
        Self {
            gas_adjuster,
            safety_margin_percent: 20, // 默认 20% 安全边距
        }
    }

    /// 获取 BSC 网络的实际 gas price 并增加安全边距
    pub async fn get_gas_price_with_margin(&self) -> u64 {
        // 尝试通过 gas_adjuster 获取当前 gas price
        let base_fee = self.gas_adjuster.get_base_fee(0);
        let priority_fee = self.gas_adjuster.get_priority_fee();

        let base_gas_price = if base_fee > 0 {
            base_fee + priority_fee
        } else {
            // 如果无法获取，使用保守的 fallback (0.1 Gwei)
            100_000_000u64
        };

        // 增加安全边距
        let gas_price_with_margin = base_gas_price * (100 + self.safety_margin_percent) / 100;

        tracing::info!(
            "BSC gas price calculation: base={} wei ({} Gwei), with {}% margin={} wei ({} Gwei)",
            base_gas_price,
            base_gas_price / 1_000_000_000,
            self.safety_margin_percent,
            gas_price_with_margin,
            gas_price_with_margin / 1_000_000_000
        );

        // 确保不会太低 (最少 0.1 Gwei) 或太高 (最多 10 Gwei)
        let min_gas_price = 100_000_000u64;  // 0.1 Gwei
        let max_gas_price = 10_000_000_000u64; // 10 Gwei

        if gas_price_with_margin < min_gas_price {
            tracing::warn!("BSC gas price {} wei too low, using minimum {} wei", gas_price_with_margin, min_gas_price);
            min_gas_price
        } else if gas_price_with_margin > max_gas_price {
            tracing::warn!("BSC gas price {} wei too high, using maximum {} wei", gas_price_with_margin, max_gas_price);
            max_gas_price
        } else {
            gas_price_with_margin
        }
    }
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

    /// 网络感知的费用检查 - 支持 BSC 动态 gas price (含 20% 安全边距)
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
                    // BSC：动态获取实际 gas price 并增加 20% 安全边距
                    match fee_type {
                        "base" => {
                            let gas_price = tokio::task::block_in_place(|| {
                                Handle::current().block_on(
                                    self.bsc_provider.get_gas_price_with_margin()
                                )
                            });

                            tracing::info!(
                                "BSC network detected: using dynamic gas price with 20% safety margin: {} wei ({} Gwei) vs hardcoded 20 Gwei",
                                gas_price,
                                gas_price / 1_000_000_000
                            );
                            gas_price
                        }
                        "blob" => {
                            // BSC 不使用 blob，返回最小值
                            let blob_fee = 100_000_000u64; // 0.1 Gwei
                            tracing::debug!("BSC blob fee (not used): {} wei", blob_fee);
                            blob_fee
                        }
                        _ => {
                            let default_fee = 500_000_000u64; // 0.5 Gwei
                            tracing::warn!("BSC unknown fee type '{}', using default: {} wei", fee_type, default_fee);
                            default_fee
                        }
                    }
                }
                NetworkType::Other => {
                    // 其他网络：使用保守默认值
                    let default_value = match fee_type {
                        "base" => 10_000_000_000u64, // 10 Gwei
                        "blob" => 1_000_000_000u64,  // 1 Gwei
                        _ => 10_000_000_000u64,
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

    /// 网络感知的优先费用检查
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
                NetworkType::Bsc | NetworkType::Other => {
                    // BSC/其他：优雅处理
                    tracing::warn!(
                        "High priority fee detected: {}, capping to max acceptable: {}",
                        priority_fee_per_gas,
                        self.max_acceptable_priority_fee_in_gwei
                    );
                    return self.max_acceptable_priority_fee_in_gwei;
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
    fn calculate_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
        operator_type: OperatorType,
    ) -> Result<EthFees, EthSenderError> {
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
