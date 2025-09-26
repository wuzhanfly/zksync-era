//! BSC-specific API handler for optimized BSC network interactions.

use std::{sync::Arc, time::Duration};

use anyhow::Context as _;
use tokio::time::Instant;
use zksync_dal::{ConnectionPool, Core, CoreDal};
use zksync_types::{
    api::{BlockId, BlockNumber, Transaction, TransactionReceipt},
    fee::Fee,
    l2::L2Tx,
    Address, H256, U256, U64,
};
use zksync_web3_decl::{
    error::Web3Error,
    types::{Filter, Log},
};

use crate::web3::metrics::API_METRICS;

/// BSC-specific configuration for API server
#[derive(Debug, Clone)]
pub struct BSCApiConfig {
    /// BSC block time in seconds (typically 3 seconds)
    pub block_time_seconds: u64,
    /// API response cache duration in seconds
    pub response_cache_duration: u64,
    /// Maximum number of blocks to return in a single request
    pub max_blocks_per_request: u64,
    /// Whether to enable fast response mode
    pub fast_response_enabled: bool,
    /// Gas price cache duration in seconds
    pub gas_price_cache_duration: u64,
    /// Maximum gas price in wei (BSC has lower gas prices)
    pub max_gas_price_wei: U256,
}

impl BSCApiConfig {
    /// Create BSC API configuration for mainnet (chain_id: 56)
    pub fn mainnet() -> Self {
        Self {
            block_time_seconds: 3,
            response_cache_duration: 1, // 1 second cache for fast responses
            max_blocks_per_request: 1000,
            fast_response_enabled: true,
            gas_price_cache_duration: 5, // 5 seconds for gas price
            max_gas_price_wei: U256::from(20_000_000_000u64), // 20 Gwei
        }
    }

    /// Create BSC API configuration for testnet (chain_id: 97)
    pub fn testnet() -> Self {
        Self {
            block_time_seconds: 3,
            response_cache_duration: 1,
            max_blocks_per_request: 2000, // More aggressive for testnet
            fast_response_enabled: true,
            gas_price_cache_duration: 5,
            max_gas_price_wei: U256::from(50_000_000_000u64), // 50 Gwei
        }
    }

    /// Detect if chain_id is BSC network
    pub fn is_bsc_network(chain_id: u64) -> bool {
        matches!(chain_id, 56 | 97)
    }

    /// Get BSC config for specific chain_id
    pub fn for_chain_id(chain_id: u64) -> Option<Self> {
        match chain_id {
            56 => Some(Self::mainnet()),
            97 => Some(Self::testnet()),
            _ => None,
        }
    }
}

/// BSC-optimized API handler
#[derive(Debug)]
pub struct BSCApiHandler {
    pool: ConnectionPool<Core>,
    config: BSCApiConfig,
    gas_price_cache: tokio::sync::RwLock<Option<(U256, Instant)>>,
    block_cache: tokio::sync::RwLock<std::collections::HashMap<u64, (serde_json::Value, Instant)>>,
}

impl BSCApiHandler {
    /// Create a new BSC API handler
    pub fn new(pool: ConnectionPool<Core>, config: BSCApiConfig) -> Self {
        Self {
            pool,
            config,
            gas_price_cache: tokio::sync::RwLock::new(None),
            block_cache: tokio::sync::RwLock::new(std::collections::HashMap::new()),
        }
    }

    /// Get BSC-optimized gas price
    pub async fn bsc_gas_price(&self) -> Result<U256, Web3Error> {
        let start_time = Instant::now();

        // Check cache first
        {
            let cache = self.gas_price_cache.read().await;
            if let Some((price, timestamp)) = *cache {
                if timestamp.elapsed().as_secs() < self.config.gas_price_cache_duration {
                    API_METRICS.bsc_api_requests.inc_by(1);
                    API_METRICS.bsc_api_response_time.observe(start_time.elapsed());
                    return Ok(price);
                }
            }
        }

        // Fetch fresh gas price
        let mut storage = self
            .pool
            .connection_tagged("bsc_api_gas_price")
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?;

        // Get base fee from latest block
        let latest_block = storage
            .blocks_dal()
            .get_sealed_l2_block_number()
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?
            .unwrap_or_default();

        let block_details = storage
            .blocks_dal()
            .get_l2_block_header(latest_block)
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?;

        let base_fee = block_details
            .map(|b| b.base_fee_per_gas)
            .unwrap_or(5_000_000_000u64); // Default 5 Gwei for BSC

        // Apply BSC-specific gas price logic
        let bsc_gas_price = self.calculate_bsc_gas_price(base_fee).await;

        // Update cache
        {
            let mut cache = self.gas_price_cache.write().await;
            *cache = Some((bsc_gas_price, Instant::now()));
        }

        API_METRICS.bsc_api_requests.inc_by(1);
        API_METRICS.bsc_api_response_time.observe(start_time.elapsed());

        Ok(bsc_gas_price)
    }

    /// Calculate BSC-specific gas price
    async fn calculate_bsc_gas_price(&self, base_fee: u64) -> U256 {
        // BSC typically has lower and more stable gas prices
        let bsc_base_fee = U256::from(base_fee);
        
        // Add small buffer for BSC (5% instead of Ethereum's higher buffer)
        let buffered_fee = bsc_base_fee * U256::from(105) / U256::from(100);
        
        // Cap at maximum BSC gas price
        std::cmp::min(buffered_fee, self.config.max_gas_price_wei)
    }

    /// Get BSC block with caching
    pub async fn get_bsc_block(
        &self,
        block_id: BlockId,
        full_transactions: bool,
    ) -> Result<Option<serde_json::Value>, Web3Error> {
        let start_time = Instant::now();

        // Convert block_id to block number for caching
        let block_number = match block_id {
            BlockId::Number(BlockNumber::Number(n)) => n.as_u64(),
            BlockId::Number(BlockNumber::Latest) => {
                let mut storage = self
                    .pool
                    .connection_tagged("bsc_api_latest_block")
                    .await
                    .map_err(|err| Web3Error::InternalError(err.into()))?;

                storage
                    .blocks_dal()
                    .get_sealed_l2_block_number()
                    .await
                    .map_err(|err| Web3Error::InternalError(err.into()))?
                    .unwrap_or_default()
                    .0 as u64
            }
            _ => {
                // For other block IDs, skip caching and fetch directly
                return self.fetch_block_from_db(block_id, full_transactions).await;
            }
        };

        // Check cache for recent blocks
        if self.config.fast_response_enabled {
            let cache = self.block_cache.read().await;
            if let Some((cached_block, timestamp)) = cache.get(&block_number) {
                if timestamp.elapsed().as_secs() < self.config.response_cache_duration {
                    API_METRICS.bsc_api_requests.inc_by(1);
                    API_METRICS.bsc_api_response_time.observe(start_time.elapsed());
                    return Ok(Some(cached_block.clone()));
                }
            }
        }

        // Fetch from database
        let block_data = self
            .fetch_block_from_db(BlockId::Number(BlockNumber::Number(block_number.into())), full_transactions)
            .await?;

        // Cache the result if enabled
        if self.config.fast_response_enabled && block_data.is_some() {
            let mut cache = self.block_cache.write().await;
            cache.insert(block_number, (block_data.as_ref().unwrap().clone(), Instant::now()));

            // Clean old cache entries (keep only last 100 blocks)
            if cache.len() > 100 {
                let oldest_key = *cache.keys().min().unwrap();
                cache.remove(&oldest_key);
            }
        }

        API_METRICS.bsc_api_requests.inc_by(1);
        API_METRICS.bsc_api_response_time.observe(start_time.elapsed());

        Ok(block_data)
    }

    /// Fetch block from database
    async fn fetch_block_from_db(
        &self,
        block_id: BlockId,
        full_transactions: bool,
    ) -> Result<Option<serde_json::Value>, Web3Error> {
        let mut storage = self
            .pool
            .connection_tagged("bsc_api_block")
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?;

        // This is a simplified implementation - in practice, you'd use the existing
        // block fetching logic from the web3 module
        let block_number = match block_id {
            BlockId::Number(BlockNumber::Number(n)) => n.as_u32().into(),
            BlockId::Number(BlockNumber::Latest) => storage
                .blocks_dal()
                .get_sealed_l2_block_number()
                .await
                .map_err(|err| Web3Error::InternalError(err.into()))?
                .unwrap_or_default(),
            _ => return Ok(None),
        };

        let block_header = storage
            .blocks_dal()
            .get_l2_block_header(block_number)
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?;

        if let Some(header) = block_header {
            // Convert to JSON format (simplified)
            let block_json = serde_json::json!({
                "number": format!("0x{:x}", header.number.0),
                "hash": format!("0x{:x}", header.hash),
                "timestamp": format!("0x{:x}", header.timestamp),
                "gasLimit": format!("0x{:x}", header.gas_limit),
                "gasUsed": "0x0", // Simplified - would need to calculate actual gas used
                "baseFeePerGas": format!("0x{:x}", header.base_fee_per_gas),
                "transactions": if full_transactions { 
                    serde_json::Value::Array(vec![]) // Simplified - would fetch actual transactions
                } else {
                    serde_json::Value::Array(vec![]) // Transaction hashes only
                }
            });

            Ok(Some(block_json))
        } else {
            Ok(None)
        }
    }

    /// Get BSC network information
    pub async fn get_bsc_network_info(&self) -> Result<BSCNetworkInfo, Web3Error> {
        let mut storage = self
            .pool
            .connection_tagged("bsc_api_network_info")
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?;

        let latest_block = storage
            .blocks_dal()
            .get_sealed_l2_block_number()
            .await
            .map_err(|err| Web3Error::InternalError(err.into()))?
            .unwrap_or_default();

        let gas_price = self.bsc_gas_price().await?;

        Ok(BSCNetworkInfo {
            latest_block: latest_block.0 as u64,
            gas_price,
            block_time: self.config.block_time_seconds,
            max_gas_price: self.config.max_gas_price_wei,
            fast_response_enabled: self.config.fast_response_enabled,
        })
    }

    /// Estimate BSC gas for transaction
    pub async fn estimate_bsc_gas(&self, tx: &L2Tx) -> Result<U256, Web3Error> {
        // BSC gas estimation with optimizations
        let base_gas = U256::from(21000); // Base transaction cost
        
        // Add contract interaction costs if applicable
        let contract_gas = if tx.execute.contract_address.is_some() {
            U256::from(50000) // Estimated contract call cost
        } else {
            U256::zero()
        };

        // BSC typically requires less gas than Ethereum
        let total_gas = base_gas + contract_gas;
        
        // Add 10% buffer for BSC (less than Ethereum's typical 20%)
        let buffered_gas = total_gas * U256::from(110) / U256::from(100);

        Ok(buffered_gas)
    }
}

/// BSC network information
#[derive(Debug, Clone)]
pub struct BSCNetworkInfo {
    pub latest_block: u64,
    pub gas_price: U256,
    pub block_time: u64,
    pub max_gas_price: U256,
    pub fast_response_enabled: bool,
}

impl BSCNetworkInfo {
    /// Check if network is healthy
    pub fn is_healthy(&self) -> bool {
        self.gas_price <= self.max_gas_price && self.latest_block > 0
    }

    /// Get network status description
    pub fn status_description(&self) -> &'static str {
        if self.is_healthy() {
            "Healthy"
        } else {
            "Degraded"
        }
    }

    /// Get gas price in Gwei
    pub fn gas_price_gwei(&self) -> f64 {
        self.gas_price.as_u64() as f64 / 1_000_000_000.0
    }
}