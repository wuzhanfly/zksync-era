//! Metrics for the synchronization layer of external node.

use std::time::Duration;

use vise::{Buckets, EncodeLabelSet, EncodeLabelValue, Family, Gauge, Histogram, Metrics};
use zksync_types::aggregated_operations::L1BatchAggregatedActionType;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, EncodeLabelValue, EncodeLabelSet)]
#[metrics(label = "stage", rename_all = "snake_case")]
pub(super) enum FetchStage {
    GetL1BatchDetails,
    GetMiniblockDetails,
    GetSafeBlock,
}

#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, EncodeLabelValue, EncodeLabelSet,
)]
#[metrics(label = "stage", rename_all = "snake_case")]
pub(super) enum L1BatchStage {
    Open,
    Committed,
    Proven,
    Executed,
}

impl From<L1BatchAggregatedActionType> for L1BatchStage {
    fn from(ty: L1BatchAggregatedActionType) -> Self {
        match ty {
            L1BatchAggregatedActionType::Commit => Self::Committed,
            L1BatchAggregatedActionType::PublishProofOnchain => Self::Proven,
            L1BatchAggregatedActionType::Execute => Self::Executed,
        }
    }
}

/// Metrics for the fetcher.
#[derive(Debug, Metrics)]
#[metrics(prefix = "external_node_fetcher")]
pub(super) struct FetcherMetrics {
    #[metrics(buckets = Buckets::LATENCIES)]
    pub requests: Family<FetchStage, Histogram<Duration>>,
    pub l1_batch: Family<L1BatchStage, Gauge<u64>>,
    // uses legacy naming for L2 blocks for compatibility reasons
    pub miniblock: Gauge<u64>,
}

#[vise::register]
pub(super) static FETCHER_METRICS: vise::Global<FetcherMetrics> = vise::Global::new();

/// BSC-specific metrics for synchronization
#[derive(Debug, Metrics)]
#[metrics(prefix = "external_node_bsc_sync")]
pub(super) struct BSCSyncMetrics {
    /// Current BSC sync progress (block number)
    pub bsc_sync_progress: Gauge<i64>,
    /// Number of BSC blocks synced
    pub bsc_blocks_synced: vise::Counter,
    /// BSC sync lag (blocks behind)
    pub bsc_sync_lag: Gauge<u64>,
    /// BSC fast sync operations
    pub bsc_fast_sync_operations: vise::Counter,
    /// BSC sync iteration duration
    #[metrics(buckets = Buckets::LATENCIES)]
    pub bsc_sync_iteration_duration: Histogram<Duration>,
    /// BSC sync errors
    pub bsc_sync_errors: vise::Counter,
}

#[vise::register]
pub(super) static BSC_SYNC_METRICS: vise::Global<BSCSyncMetrics> = vise::Global::new();



#[derive(Debug, Metrics)]
#[metrics(prefix = "external_node_action_queue")]
pub(super) struct ActionQueueMetrics {
    pub action_queue_size: Gauge<usize>,
}

#[vise::register]
pub(super) static QUEUE_METRICS: vise::Global<ActionQueueMetrics> = vise::Global::new();
