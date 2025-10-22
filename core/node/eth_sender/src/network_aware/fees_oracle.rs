//! 网络感知的费用 Oracle
//! 根据网络类型选择合适的费用计算策略

use std::sync::Arc;
use zksync_node_fee_model::l1_gas_price::TxParamsProvider;
use zksync_types::{eth_sender::TxHistory, L1ChainId};

use crate::{
    abstract_l1_interface::OperatorType,
    eth_fees_oracle::{EthFees, EthFeesOracle, GasAdjusterFeesOracle},
    EthSenderError,
};
use super::{NetworkType, detect_network_type};

/// BSC 网络的默认 gas 价格配置
const BSC_DEFAULT_GAS_PRICE: u64 = 20_000_000_000; // 20 Gwei
const BSC_DEFAULT_PRIORITY_FEE: u64 = 1_000_000_000; // 1 Gwei

/// 网络感知的费用 Oracle
/// 根据网络类型自动选择合适的费用计算策略
#[derive(Debug)]
pub struct NetworkAwareFeesOracle {
    /// 原始的 GasAdjusterFeesOracle (用于以太坊)
    inner: GasAdjusterFeesOracle,
    /// 网络类型
    network_type: NetworkType,
    /// 链 ID
    chain_id: L1ChainId,
}

impl NetworkAwareFeesOracle {
    pub fn new(
        gas_adjuster: Arc<dyn TxParamsProvider>,
        max_acceptable_priority_fee_in_gwei: u64,
        time_in_mempool_in_l1_blocks_cap: u32,
        max_acceptable_base_fee_in_wei: u64,
        chain_id: L1ChainId,
    ) -> Self {
        let network_type = detect_network_type(chain_id);
        
        tracing::info!(
            "Initializing NetworkAwareFeesOracle for chain_id={}, network_type={:?}",
            chain_id.0,
            network_type
        );

        let inner = GasAdjusterFeesOracle {
            gas_adjuster,
            max_acceptable_priority_fee_in_gwei,
            time_in_mempool_in_l1_blocks_cap,
            max_acceptable_base_fee_in_wei,
        };

        Self {
            inner,
            network_type,
            chain_id,
        }
    }

    /// 计算 BSC 网络的费用
    fn calculate_bsc_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
        operator_type: OperatorType,
    ) -> Result<EthFees, EthSenderError> {
        // BSC 使用简单的 gas 价格模型
        let mut base_fee_per_gas = BSC_DEFAULT_GAS_PRICE;
        let mut priority_fee_per_gas = BSC_DEFAULT_PRIORITY_FEE;

        // 如果有之前的交易，适当提高费用以确保新交易被处理
        if let Some(previous_tx) = previous_sent_tx {
            const PRICE_BUMP_MULTIPLIER: u64 = 2; // 100% 增加
            
            base_fee_per_gas = base_fee_per_gas.max(
                previous_tx.base_fee_per_gas * PRICE_BUMP_MULTIPLIER
            );
            priority_fee_per_gas = priority_fee_per_gas.max(
                previous_tx.priority_fee_per_gas * PRICE_BUMP_MULTIPLIER
            );

            tracing::info!(
                "BSC fee bump: previous_base={}, new_base={}, previous_priority={}, new_priority={}",
                previous_tx.base_fee_per_gas,
                base_fee_per_gas,
                previous_tx.priority_fee_per_gas,
                priority_fee_per_gas
            );
        }

        // 根据在内存池中的时间调整费用
        if time_in_mempool_in_l1_blocks > 0 {
            let time_multiplier = 1.0 + (time_in_mempool_in_l1_blocks as f64 * 0.1); // 每个区块增加 10%
            base_fee_per_gas = (base_fee_per_gas as f64 * time_multiplier) as u64;
            priority_fee_per_gas = (priority_fee_per_gas as f64 * time_multiplier) as u64;
        }

        // 确保费用不超过最大限制
        if base_fee_per_gas > self.inner.max_acceptable_base_fee_in_wei {
            tracing::warn!(
                "BSC base fee {} exceeds max acceptable {}, capping it",
                base_fee_per_gas,
                self.inner.max_acceptable_base_fee_in_wei
            );
            return Err(EthSenderError::ExceedMaxBaseFee);
        }

        if priority_fee_per_gas > self.inner.max_acceptable_priority_fee_in_gwei {
            tracing::warn!(
                "BSC priority fee {} exceeds max acceptable {}, capping it",
                priority_fee_per_gas,
                self.inner.max_acceptable_priority_fee_in_gwei
            );
            priority_fee_per_gas = self.inner.max_acceptable_priority_fee_in_gwei;
        }

        tracing::debug!(
            "BSC fees calculated: base_fee={}, priority_fee={}, operator_type={:?}",
            base_fee_per_gas,
            priority_fee_per_gas,
            operator_type
        );

        Ok(EthFees {
            base_fee_per_gas,
            priority_fee_per_gas,
            blob_base_fee_per_gas: None, // BSC 不支持 blob
            max_gas_per_pubdata_price: None,
        })
    }

    /// 计算其他 Legacy 网络的费用
    fn calculate_legacy_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
        operator_type: OperatorType,
    ) -> Result<EthFees, EthSenderError> {
        // 对于其他网络，使用类似 BSC 的策略但参数可能不同
        self.calculate_bsc_fees(previous_sent_tx, time_in_mempool_in_l1_blocks, operator_type)
    }
}

impl EthFeesOracle for NetworkAwareFeesOracle {
    fn calculate_fees(
        &self,
        previous_sent_tx: &Option<TxHistory>,
        time_in_mempool_in_l1_blocks: u32,
        operator_type: OperatorType,
    ) -> Result<EthFees, EthSenderError> {
        match self.network_type {
            NetworkType::Ethereum => {
                // 对于以太坊，使用原始的 EIP-1559 逻辑
                tracing::debug!("Using Ethereum EIP-1559 fee calculation");
                self.inner.calculate_fees(
                    previous_sent_tx,
                    time_in_mempool_in_l1_blocks,
                    operator_type,
                )
            }
            NetworkType::Bsc => {
                // 对于 BSC，使用 Legacy 费用计算
                tracing::debug!("Using BSC Legacy fee calculation");
                self.calculate_bsc_fees(
                    previous_sent_tx,
                    time_in_mempool_in_l1_blocks,
                    operator_type,
                )
            }
            NetworkType::Other => {
                // 对于其他网络，使用 Legacy 费用计算
                tracing::debug!("Using Legacy fee calculation for other network");
                self.calculate_legacy_fees(
                    previous_sent_tx,
                    time_in_mempool_in_l1_blocks,
                    operator_type,
                )
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    use zksync_node_fee_model::l1_gas_price::TxParamsProvider;

    // Mock TxParamsProvider for testing
    struct MockTxParamsProvider;

    impl TxParamsProvider for MockTxParamsProvider {
        fn get_base_fee(&self, _time_in_mempool_in_l1_blocks: u32) -> u64 { 20_000_000_000 }
        fn get_priority_fee(&self) -> u64 { 1_000_000_000 }
        fn get_next_block_minimal_base_fee(&self) -> u64 { 15_000_000_000 }
        fn get_blob_tx_base_fee(&self, _time_in_mempool_in_l1_blocks: u32) -> u64 { 20_000_000_000 }
        fn get_blob_tx_blob_base_fee(&self, _time_in_mempool_in_l1_blocks: u32) -> u64 { 1_000_000_000 }
        fn get_blob_tx_priority_fee(&self) -> u64 { 1_000_000_000 }
        fn get_next_block_minimal_blob_base_fee(&self) -> u64 { 800_000_000 }
        fn gateway_get_base_fee(&self, _time_in_mempool_in_l1_blocks: u32) -> u64 { 20_000_000_000 }
        fn get_gateway_l2_pubdata_price(&self, _time_in_mempool_in_l1_blocks: u32) -> u64 { 1000 }
        fn get_gateway_price_per_pubdata(&self, _time_in_mempool_in_l1_blocks: u32) -> u64 { 1000 }
        fn get_parameter_b(&self) -> f64 { 1.1 }
    }

    #[test]
    fn test_bsc_fee_calculation() {
        let oracle = NetworkAwareFeesOracle::new(
            Arc::new(MockTxParamsProvider),
            100_000_000_000, // 100 Gwei max priority fee
            100,             // max time in mempool
            200_000_000_000, // 200 Gwei max base fee
            L1ChainId(97),   // BSC Testnet
        );

        let fees = oracle.calculate_fees(
            &None,
            0,
            OperatorType::NonBlob,
        ).unwrap();

        assert_eq!(fees.base_fee_per_gas, BSC_DEFAULT_GAS_PRICE);
        assert_eq!(fees.priority_fee_per_gas, BSC_DEFAULT_PRIORITY_FEE);
        assert!(fees.blob_base_fee_per_gas.is_none());
    }
}
