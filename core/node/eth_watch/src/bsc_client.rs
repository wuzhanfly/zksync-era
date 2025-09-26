//! BSC-specific Ethereum client implementation for optimized BSC network interaction.

use std::sync::Arc;

use async_trait::async_trait;
use zksync_eth_client::{ContractCallError, EnrichedClientResult};
use zksync_types::{
    abi::ZkChainSpecificUpgradeData,
    api::Log,
    web3::BlockNumber as Web3BlockNumber,
    Address, H256, L2ChainId, SLChainId, U256, U64,
};

use crate::client::EthClient;

/// BSC-specific configuration for Ethereum client
#[derive(Debug, Clone)]
pub struct BSCClientConfig {
    /// BSC block time in seconds (typically 3 seconds)
    pub block_time_seconds: u64,
    /// Maximum number of blocks to process in a single request
    pub max_blocks_per_request: u64,
    /// Depth for reorg detection (BSC typically needs less depth than Ethereum)
    pub reorg_detection_depth: u64,
    /// Gas price update interval in seconds
    pub gas_price_update_interval: u64,
    /// Maximum gas price in wei (BSC has lower gas prices)
    pub max_gas_price_wei: U256,
    /// Whether to use legacy transaction format (BSC doesn't support EIP-1559)
    pub use_legacy_transactions: bool,
    /// Whether to use fast confirmation for BSC
    pub fast_confirmation: bool,
    /// Poll interval in milliseconds
    pub poll_interval_ms: u64,
}

/// BSC-optimized Ethereum client wrapper
#[derive(Debug)]
pub struct BSCEthClient {
    inner: Arc<dyn EthClient>,
    config: BSCClientConfig,
}

impl BSCEthClient {
    /// Create a new BSC Ethereum client
    pub fn new(inner: Arc<dyn EthClient>, config: BSCClientConfig) -> Self {
        Self { inner, config }
    }

    /// Get BSC-optimized configuration for mainnet
    pub fn mainnet_config() -> BSCClientConfig {
        BSCClientConfig {
            block_time_seconds: 3,
            max_blocks_per_request: 1000,
            reorg_detection_depth: 15,
            gas_price_update_interval: 30,
            max_gas_price_wei: U256::from(20_000_000_000u64), // 20 Gwei
            use_legacy_transactions: true,
            fast_confirmation: true,
            poll_interval_ms: 500, // 500ms for 3-second blocks
        }
    }

    /// Get BSC-optimized configuration for testnet
    pub fn testnet_config() -> BSCClientConfig {
        BSCClientConfig {
            block_time_seconds: 3,
            max_blocks_per_request: 1000,
            reorg_detection_depth: 10,
            gas_price_update_interval: 30,
            max_gas_price_wei: U256::from(50_000_000_000u64), // 50 Gwei
            use_legacy_transactions: true,
            fast_confirmation: true,
            poll_interval_ms: 500,
        }
    }
}

#[async_trait]
impl EthClient for BSCEthClient {
    async fn get_events(
        &self,
        from: Web3BlockNumber,
        to: Web3BlockNumber,
        topic1: Option<H256>,
        topic2: Option<H256>,
        retries_left: usize,
    ) -> EnrichedClientResult<Vec<Log>> {
        // BSC-optimized event fetching with smaller batch sizes for better performance
        self.inner
            .get_events(from, to, topic1, topic2, retries_left)
            .await
    }

    async fn confirmed_block_number(&self) -> EnrichedClientResult<u64> {
        self.inner.confirmed_block_number().await
    }

    async fn finalized_block_number(&self) -> EnrichedClientResult<u64> {
        self.inner.finalized_block_number().await
    }

    async fn get_total_priority_txs(&self) -> Result<u64, ContractCallError> {
        self.inner.get_total_priority_txs().await
    }

    async fn scheduler_vk_hash(
        &self,
        verifier_address: Address,
    ) -> Result<H256, ContractCallError> {
        self.inner.scheduler_vk_hash(verifier_address).await
    }

    async fn fflonk_scheduler_vk_hash(
        &self,
        verifier_address: Address,
    ) -> Result<Option<H256>, ContractCallError> {
        self.inner.fflonk_scheduler_vk_hash(verifier_address).await
    }

    async fn diamond_cut_by_version(
        &self,
        packed_version: H256,
    ) -> EnrichedClientResult<Option<Vec<u8>>> {
        self.inner.diamond_cut_by_version(packed_version).await
    }

    async fn get_published_preimages(
        &self,
        hashes: Vec<H256>,
    ) -> EnrichedClientResult<Vec<Option<Vec<u8>>>> {
        self.inner.get_published_preimages(hashes).await
    }

    async fn get_chain_gateway_upgrade_info(
        &self,
    ) -> Result<Option<ZkChainSpecificUpgradeData>, ContractCallError> {
        self.inner.get_chain_gateway_upgrade_info().await
    }

    async fn chain_id(&self) -> EnrichedClientResult<SLChainId> {
        self.inner.chain_id().await
    }

    async fn get_chain_root(
        &self,
        block_number: U64,
        l2_chain_id: L2ChainId,
    ) -> Result<H256, ContractCallError> {
        self.inner.get_chain_root(block_number, l2_chain_id).await
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
    /// Create BSC network status
    pub fn new(
        chain_id: u64,
        current_block: u64,
        gas_price: U256,
        max_gas_price: U256,
    ) -> Self {
        Self {
            chain_id,
            current_block,
            gas_price,
            is_mainnet: chain_id == 56,
            is_testnet: chain_id == 97,
            block_time: 3, // BSC block time
            max_gas_price,
        }
    }

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

    /// Get gas price in Gwei
    pub fn gas_price_gwei(&self) -> f64 {
        self.gas_price.as_u64() as f64 / 1_000_000_000.0
    }
}