//! BSC-specific synchronization manager for optimized BSC network sync.

use std::{sync::Arc, time::Duration};

use anyhow::Context as _;
use tokio::time::sleep;
use zksync_dal::{ConnectionPool, Core, CoreDal};
use zksync_types::{
    api::BlockId, L1BatchNumber, L2BlockNumber, H256, U64,
};

use crate::{
    client::MainNodeClient,
    metrics::BSC_SYNC_METRICS,
    sync_action::ActionQueue,
};

/// BSC-specific configuration for node synchronization
#[derive(Debug, Clone)]
pub struct BSCSyncConfig {
    /// BSC block time in seconds (typically 3 seconds)
    pub block_time_seconds: u64,
    /// Sync interval in milliseconds (optimized for BSC's faster blocks)
    pub sync_interval_ms: u64,
    /// Maximum number of blocks to sync in a single batch
    pub max_blocks_per_batch: u64,
    /// Whether to use fast sync mode for BSC
    pub fast_sync_enabled: bool,
    /// Confirmation depth for BSC (fewer confirmations needed)
    pub confirmation_depth: u64,
    /// Maximum sync lag before triggering fast sync
    pub max_sync_lag: u64,
}

impl BSCSyncConfig {
    /// Create BSC sync configuration for mainnet (chain_id: 56)
    pub fn mainnet() -> Self {
        Self {
            block_time_seconds: 3,
            sync_interval_ms: 500, // 500ms for 3-second blocks
            max_blocks_per_batch: 100,
            fast_sync_enabled: true,
            confirmation_depth: 15,
            max_sync_lag: 1000,
        }
    }

    /// Create BSC sync configuration for testnet (chain_id: 97)
    pub fn testnet() -> Self {
        Self {
            block_time_seconds: 3,
            sync_interval_ms: 500,
            max_blocks_per_batch: 200, // More aggressive for testnet
            fast_sync_enabled: true,
            confirmation_depth: 10,
            max_sync_lag: 500,
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

/// BSC-optimized synchronization manager
#[derive(Debug)]
pub struct BSCSyncManager {
    client: Arc<dyn MainNodeClient>,
    pool: ConnectionPool<Core>,
    config: BSCSyncConfig,
    action_queue: ActionQueue,
}

impl BSCSyncManager {
    /// Create a new BSC sync manager
    pub fn new(
        client: Arc<dyn MainNodeClient>,
        pool: ConnectionPool<Core>,
        config: BSCSyncConfig,
        action_queue: ActionQueue,
    ) -> Self {
        Self {
            client,
            pool,
            config,
            action_queue,
        }
    }

    /// Start BSC-optimized synchronization
    pub async fn run(self) -> anyhow::Result<()> {
        tracing::info!("Starting BSC sync manager with config: {:?}", self.config);

        let mut sync_interval = tokio::time::interval(Duration::from_millis(self.config.sync_interval_ms));
        sync_interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

        loop {
            sync_interval.tick().await;

            if let Err(err) = self.sync_iteration().await {
                tracing::error!("BSC sync iteration failed: {err:?}");
                // Continue syncing even if one iteration fails
                sleep(Duration::from_secs(1)).await;
            }
        }
    }

    /// Perform one BSC sync iteration
    async fn sync_iteration(&self) -> anyhow::Result<()> {
        let mut storage = self.pool.connection_tagged("bsc_sync").await?;

        // Get current local state
        let local_block = storage
            .blocks_dal()
            .get_sealed_l2_block_number()
            .await?
            .unwrap_or(L2BlockNumber(0));

        // Get remote state from main node
        let remote_block = self
            .client
            .fetch_l2_block_number()
            .await
            .context("Failed to fetch remote block number")?;

        let sync_lag = remote_block.0.saturating_sub(local_block.0);

        // Update metrics
        BSC_SYNC_METRICS.bsc_sync_progress.set(local_block.0 as i64);
        BSC_SYNC_METRICS.bsc_blocks_synced.inc_by(1);

        if sync_lag == 0 {
            // Already synced
            return Ok(());
        }

        tracing::debug!(
            "BSC sync: local={}, remote={}, lag={}",
            local_block.0,
            remote_block.0,
            sync_lag
        );

        // Determine sync strategy
        if sync_lag as u64 > self.config.max_sync_lag && self.config.fast_sync_enabled {
            self.fast_sync(local_block, remote_block).await?;
        } else {
            self.incremental_sync(local_block, remote_block).await?;
        }

        Ok(())
    }

    /// Perform fast sync for large gaps
    async fn fast_sync(
        &self,
        local_block: L2BlockNumber,
        remote_block: L2BlockNumber,
    ) -> anyhow::Result<()> {
        tracing::info!(
            "Starting BSC fast sync from {} to {}",
            local_block.0,
            remote_block.0
        );

        let mut current_block = local_block;
        while current_block < remote_block {
            let end_block = std::cmp::min(
                L2BlockNumber(current_block.0 + self.config.max_blocks_per_batch as u32),
                remote_block,
            );

            self.sync_block_range(current_block, end_block).await?;
            current_block = end_block;

            // Small delay to prevent overwhelming the main node
            sleep(Duration::from_millis(10)).await;
        }

        tracing::info!("BSC fast sync completed");
        Ok(())
    }

    /// Perform incremental sync for small gaps
    async fn incremental_sync(
        &self,
        local_block: L2BlockNumber,
        remote_block: L2BlockNumber,
    ) -> anyhow::Result<()> {
        let next_block = local_block + 1;
        if next_block <= remote_block {
            self.sync_single_block(next_block).await?;
        }
        Ok(())
    }

    /// Sync a range of blocks
    async fn sync_block_range(
        &self,
        start_block: L2BlockNumber,
        end_block: L2BlockNumber,
    ) -> anyhow::Result<()> {
        for block_number in start_block.0..end_block.0 {
            self.sync_single_block(L2BlockNumber(block_number + 1)).await?;
        }
        Ok(())
    }

    /// Sync a single block
    async fn sync_single_block(&self, block_number: L2BlockNumber) -> anyhow::Result<()> {
        // Fetch block data from main node
        let block_data = self
            .client
            .fetch_l2_block(block_number, true)
            .await
            .context("Failed to fetch block data")?;

        if let Some(_block) = block_data {
            // For now, just log the sync - actual sync logic would be implemented here
            tracing::debug!("BSC block {} fetched for sync", block_number.0);
        }

        Ok(())
    }

    /// Get BSC sync status
    pub async fn get_sync_status(&self) -> anyhow::Result<BSCSyncStatus> {
        let mut storage = self.pool.connection_tagged("bsc_sync_status").await?;

        let local_block = storage
            .blocks_dal()
            .get_sealed_l2_block_number()
            .await?
            .unwrap_or(L2BlockNumber(0));

        let remote_block = self
            .client
            .fetch_l2_block_number()
            .await
            .context("Failed to fetch remote block number")?;

        let sync_lag = remote_block.0.saturating_sub(local_block.0);
        let is_synced = sync_lag as u64 <= self.config.confirmation_depth;

        Ok(BSCSyncStatus {
            local_block: local_block.0,
            remote_block: remote_block.0,
            sync_lag,
            is_synced,
            sync_progress: if remote_block.0 > 0 {
                (local_block.0 as f64 / remote_block.0 as f64) * 100.0
            } else {
                100.0
            },
        })
    }
}

/// BSC synchronization status
#[derive(Debug, Clone)]
pub struct BSCSyncStatus {
    pub local_block: u32,
    pub remote_block: u32,
    pub sync_lag: u32,
    pub is_synced: bool,
    pub sync_progress: f64,
}

impl BSCSyncStatus {
    /// Check if sync is healthy
    pub fn is_healthy(&self) -> bool {
        self.is_synced && self.sync_lag < 100
    }

    /// Get sync status description
    pub fn status_description(&self) -> &'static str {
        if self.is_synced {
            "Synced"
        } else if self.sync_lag < 10 {
            "Catching up"
        } else if self.sync_lag < 100 {
            "Syncing"
        } else {
            "Behind"
        }
    }
}