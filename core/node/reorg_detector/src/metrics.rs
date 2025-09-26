//! Metrics for BSC reorg detector.

/// BSC reorg detection metrics (simplified)
pub struct BSCReorgMetrics {
    pub bsc_reorgs_detected: u64,
    pub bsc_reorg_depth: i64,
}

impl BSCReorgMetrics {
    pub fn new() -> Self {
        Self {
            bsc_reorgs_detected: 0,
            bsc_reorg_depth: 0,
        }
    }
}

// Global metrics instance
pub static BSC_REORG_METRICS: std::sync::LazyLock<std::sync::Mutex<BSCReorgMetrics>> = 
    std::sync::LazyLock::new(|| std::sync::Mutex::new(BSCReorgMetrics::new()));