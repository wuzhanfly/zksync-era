//! 网络感知的 ETH Sender 工厂
//! 根据网络类型创建合适的组件

use std::sync::Arc;
use zksync_config::EthSenderConfig;
use zksync_node_fee_model::l1_gas_price::TxParamsProvider;
use zksync_types::L1ChainId;

use crate::{
    eth_fees_oracle::{EthFeesOracle, GasAdjusterFeesOracle},
    network_aware::{NetworkAwareFeesOracle, NetworkType, detect_network_type},
};

/// 创建网络感知的费用 Oracle
pub fn create_network_aware_fees_oracle(
    gas_adjuster: Arc<dyn TxParamsProvider>,
    config: &EthSenderConfig,
    chain_id: L1ChainId,
) -> Box<dyn EthFeesOracle> {
    let network_type = detect_network_type(chain_id);
    
    match network_type {
        NetworkType::Ethereum => {
            tracing::info!("Creating Ethereum-compatible fees oracle with EIP-1559 support");
            Box::new(GasAdjusterFeesOracle {
                gas_adjuster,
                max_acceptable_priority_fee_in_gwei: config.max_acceptable_priority_fee_in_gwei,
                time_in_mempool_in_l1_blocks_cap: config.time_in_mempool_in_l1_blocks_cap,
                max_acceptable_base_fee_in_wei: config.max_acceptable_base_fee_in_wei,
            })
        }
        NetworkType::Bsc | NetworkType::Other => {
            tracing::info!("Creating network-aware fees oracle for {:?} network", network_type);
            Box::new(NetworkAwareFeesOracle::new(
                gas_adjuster,
                config.max_acceptable_priority_fee_in_gwei,
                config.time_in_mempool_in_l1_blocks_cap,
                config.max_acceptable_base_fee_in_wei,
                chain_id,
            ))
        }
    }
}
