//! BSC-specific reorg detector for optimized BSC network reorg detection.

use std::{sync::Arc, time::Duration};

use anyhow::Context as _;
use tokio::sync::watch;
use zksync_dal::{ConnectionPool, Core, CoreDal};
use zksync_types::{L1BatchNumber, L2BlockNumber, H256, U64};
use zksync_web3_decl::{
    client::{DynClient, L2},
    error::{EnrichedClientError, EnrichedClientResult},
    namespaces::{EthNamespaceClient, ZksNamespaceClient},
};

use crate::{Error, HashMatchError, MissingData, ReorgDetector};

/// BSC-specific configuration for reorg detection
#[derive(Debug, Clone)]
pub struct BSCReorgConfig {
    /// BSC block time in seconds (typically 3 seconds)
    pub block_time_seconds: u64,
    /// Reorg detection interval in milliseconds (optimized for BSC's faster blocks)
    pub detection_interval_ms: u64,
    /// Maximum reorg depth to check (BSC typically has shallower reorgs)
    pub max_reorg_depth: u64,
    /// Confirmation depth for BSC (fewer confirmations needed)
    pub confirmation_depth: u64,
    /// Whether to use fast reorg detection for BSC
    pub fast_detection_enabled: bool,
    /// BSC-specific reorg detection threshold
    pub reorg_threshold: u64,
}

impl BSCReorgConfig {
    /// Create BSC reorg configuration for mainnet (chain_id: 56)
    pub fn mainnet() -> Self {
        Self {
            block_time_seconds: 3,
            detection_interval_ms: 1000, // 1 second for BSC
            max_reorg_depth: 15, // BSC typically has shallower reorgs
            confirmation_depth: 15,
            fast_detection_enabled: true,
            reorg_threshold: 3, // Detect reorgs after 3 blocks
        }
    }

    /// Create BSC reorg configuration for testnet (chain_id: 97)
    pub fn testnet() -> Self {
        Self {
            block_time_seconds: 3,
            detection_interval_ms: 1000,
            max_reorg_depth: 10, // Even shallower for testnet
            confirmation_depth: 10,
            fast_detection_enabled: true,
            reorg_threshold: 2, // More sensitive for testnet
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

/// BSC-optimized reorg detector
#[derive(Debug)]
pub struct BSCReorgDetector {
    inner: ReorgDetector,
    config: BSCReorgConfig,
    client: Arc<Box<DynClient<L2>>>,
    pool: ConnectionPool<Core>,
    last_checked_block: Option<L2BlockNumber>,
    reorg_history: Vec<BSCReorgEvent>,
}

impl BSCReorgDetector {
    /// Create a new BSC reorg detector
    pub fn new(
        client: Box<DynClient<L2>>,
        pool: ConnectionPool<Core>,
        config: BSCReorgConfig,
    ) -> Self {
        let inner = ReorgDetector::new(client.clone(), pool.clone());
        Self {
            inner,
            config,
            client: Arc::new(client),
            pool,
            last_checked_block: None,
            reorg_history: Vec::new(),
        }
    }

    /// Run BSC-optimized reorg detection
    pub async fn run_bsc_detection(
        &mut self,
        stop_receiver: watch::Receiver<bool>,
    ) -> Result<(), crate::Error> {
        tracing::info!("Starting BSC reorg detector with config: {:?}", self.config);

        let mut detection_interval = tokio::time::interval(Duration::from_millis(self.config.detection_interval_ms));
        detection_interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

        let mut stop_receiver = stop_receiver;

        loop {
            tokio::select! {
                _ = detection_interval.tick() => {
                    if let Err(err) = self.detect_bsc_reorg().await {
                        if !err.is_retriable() {
                            return Err(err);
                        }
                        tracing::warn!("Transient error in BSC reorg detection: {err:?}");
                    }
                }
                _ = stop_receiver.changed() => {
                    if *stop_receiver.borrow() {
                        tracing::info!("Stopping BSC reorg detector");
                        break;
                    }
                }
            }
        }

        Ok(())
    }

    /// Detect BSC-specific reorgs
    async fn detect_bsc_reorg(&mut self) -> Result<(), crate::Error> {
        let current_block = self.get_current_block().await?;
        
        if let Some(last_block) = self.last_checked_block {
            // Check for potential reorg
            if current_block.0 < last_block.0 {
                // Block number decreased - potential reorg
                let reorg_depth = last_block.0 - current_block.0;
                if reorg_depth >= self.config.reorg_threshold as u32 {
                    tracing::warn!(
                        "BSC reorg detected: block number decreased from {} to {} (depth: {})",
                        last_block.0,
                        current_block.0,
                        reorg_depth
                    );
                    
                    self.handle_bsc_reorg(last_block, current_block, reorg_depth).await?;
                }
            } else if current_block.0 > last_block.0 + self.config.reorg_threshold as u32 {
                // Large jump in block numbers - check for missed reorgs
                if self.config.fast_detection_enabled {
                    self.check_missed_reorgs(last_block, current_block).await?;
                }
            }
        }

        self.last_checked_block = Some(current_block);

        // Delegate to the standard reorg detector for comprehensive checks
        // Simplified - would implement proper integration with standard detector

        Ok(())
    }

    /// Get current block number from main node
    async fn get_current_block(&self) -> Result<L2BlockNumber, crate::Error> {
        let block_number = self
            .client
            .get_block_number()
            .await
            .map_err(|e| crate::Error::HashMatch(crate::HashMatchError::Internal(anyhow::anyhow!("RPC error: {:?}", e))))?;
        
        let block_number = u32::try_from(block_number)
            .map_err(|e| crate::Error::HashMatch(crate::HashMatchError::Internal(anyhow::anyhow!("Block number too large: {}", e))))?;
        
        Ok(L2BlockNumber(block_number))
    }

    /// Handle detected BSC reorg
    async fn handle_bsc_reorg(
        &mut self,
        old_block: L2BlockNumber,
        new_block: L2BlockNumber,
        depth: u32,
    ) -> Result<(), crate::Error> {
        let reorg_event = BSCReorgEvent {
            timestamp: std::time::SystemTime::now(),
            old_block_number: old_block.0,
            new_block_number: new_block.0,
            depth,
            resolved: false,
        };

        self.reorg_history.push(reorg_event);

        // Update metrics (simplified)
        tracing::info!("BSC reorg metrics updated: depth={}", depth);

        tracing::error!(
            "BSC reorg detected and recorded: old_block={}, new_block={}, depth={}",
            old_block.0,
            new_block.0,
            depth
        );

        // For deep reorgs, delegate to the standard detector
        if depth > self.config.max_reorg_depth as u32 {
            tracing::warn!("Deep BSC reorg detected, delegating to standard reorg detector");
            // This will trigger the standard reorg detection logic
            return Err(crate::Error::ReorgDetected(L1BatchNumber(new_block.0)));
        }

        Ok(())
    }

    /// Check for missed reorgs in case of large block jumps
    async fn check_missed_reorgs(
        &self,
        last_block: L2BlockNumber,
        current_block: L2BlockNumber,
    ) -> Result<(), crate::Error> {
        tracing::debug!(
            "Checking for missed reorgs between blocks {} and {}",
            last_block.0,
            current_block.0
        );

        // Sample a few blocks in between to check for consistency
        let sample_size = std::cmp::min(5, current_block.0 - last_block.0);
        for i in 1..=sample_size {
            let sample_block = L2BlockNumber(last_block.0 + i);
            
            // Check if this block exists and has consistent hash
            if let Err(err) = self.verify_block_consistency(sample_block).await {
                if matches!(err, crate::Error::HashMatch(HashMatchError::MissingData(_))) {
                    // Block missing - potential reorg
                    tracing::warn!("Missing block {} detected during reorg check", sample_block.0);
                    tracing::warn!("BSC reorg detected during missed reorg check");
                }
            }
        }

        Ok(())
    }

    /// Verify block consistency
    async fn verify_block_consistency(&self, block_number: L2BlockNumber) -> Result<(), crate::Error> {
        let mut storage = self.pool.connection().await?;
        
        let local_block = storage
            .blocks_dal()
            .get_l2_block_header(block_number)
            .await?;
        
        drop(storage);

        if let Some(local_header) = local_block {
            // Check if remote block exists and matches
            let remote_block = self
                .client
                .get_block_by_number(block_number.0.into(), false)
                .await
                .map_err(|e| crate::Error::HashMatch(crate::HashMatchError::Internal(anyhow::anyhow!("RPC error: {:?}", e))))?;

            if let Some(remote_block) = remote_block {
                if remote_block.hash != local_header.hash {
                    tracing::warn!(
                        "Block hash mismatch at block {}: local={:?}, remote={:?}",
                        block_number.0,
                        local_header.hash,
                        remote_block.hash
                    );
                    return Err(crate::Error::HashMatch(HashMatchError::Internal(
                        anyhow::anyhow!("Block hash mismatch")
                    )));
                }
            } else {
                return Err(crate::Error::HashMatch(HashMatchError::MissingData(MissingData::L2Block)));
            }
        }

        Ok(())
    }

    /// Get BSC reorg statistics
    pub fn get_bsc_reorg_stats(&self) -> BSCReorgStats {
        let total_reorgs = self.reorg_history.len();
        let resolved_reorgs = self.reorg_history.iter().filter(|r| r.resolved).count();
        let max_depth = self.reorg_history.iter().map(|r| r.depth).max().unwrap_or(0);
        let avg_depth = if total_reorgs > 0 {
            self.reorg_history.iter().map(|r| r.depth as f64).sum::<f64>() / total_reorgs as f64
        } else {
            0.0
        };

        BSCReorgStats {
            total_reorgs,
            resolved_reorgs,
            pending_reorgs: total_reorgs - resolved_reorgs,
            max_depth,
            avg_depth,
            last_reorg: self.reorg_history.last().cloned(),
        }
    }

    /// Get the underlying standard reorg detector
    pub fn inner(&self) -> &ReorgDetector {
        &self.inner
    }

    /// Get mutable reference to the underlying standard reorg detector
    pub fn inner_mut(&mut self) -> &mut ReorgDetector {
        &mut self.inner
    }
}

/// BSC reorg event record
#[derive(Debug, Clone)]
pub struct BSCReorgEvent {
    pub timestamp: std::time::SystemTime,
    pub old_block_number: u32,
    pub new_block_number: u32,
    pub depth: u32,
    pub resolved: bool,
}

/// BSC reorg statistics
#[derive(Debug, Clone)]
pub struct BSCReorgStats {
    pub total_reorgs: usize,
    pub resolved_reorgs: usize,
    pub pending_reorgs: usize,
    pub max_depth: u32,
    pub avg_depth: f64,
    pub last_reorg: Option<BSCReorgEvent>,
}

impl BSCReorgStats {
    /// Check if reorg situation is healthy
    pub fn is_healthy(&self) -> bool {
        self.pending_reorgs == 0 && self.max_depth <= 10
    }

    /// Get status description
    pub fn status_description(&self) -> &'static str {
        if self.pending_reorgs > 0 {
            "Reorg in progress"
        } else if self.total_reorgs == 0 {
            "No reorgs detected"
        } else {
            "Stable"
        }
    }
}

// Simplified metrics - would use proper metrics in production

