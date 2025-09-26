//! Metrics for Ethereum watcher.

use std::time::Duration;

use vise::{Buckets, Counter, EncodeLabelSet, EncodeLabelValue, Family, Gauge, Histogram, Metrics};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, EncodeLabelValue, EncodeLabelSet)]
#[metrics(label = "stage", rename_all = "snake_case")]
pub(super) enum PollStage {
    PersistL1Txs,
    PersistUpgrades,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, EncodeLabelValue, EncodeLabelSet)]
#[metrics(label = "network", rename_all = "snake_case")]
pub(super) enum NetworkType {
    Ethereum,
    BSCMainnet,
    BSCTestnet,
}

#[derive(Debug, Metrics)]
#[metrics(prefix = "server_eth_watch")]
pub(super) struct EthWatcherMetrics {
    /// Number of times Ethereum was polled.
    pub eth_poll: Counter,
    /// Latency of polling and processing events split by stage.
    #[metrics(buckets = Buckets::LATENCIES)]
    pub poll_eth_node: Family<PollStage, Histogram<Duration>>,
    /// BSC-specific metrics
    /// Number of BSC gas price updates
    pub bsc_gas_price_updates: Counter,
    /// Number of BSC events processed
    pub bsc_events_processed: Counter,
    /// Current BSC gas price in Gwei
    pub bsc_current_gas_price_gwei: Gauge<f64>,
    /// BSC block processing time
    #[metrics(buckets = Buckets::LATENCIES)]
    pub bsc_block_processing_time: Histogram<Duration>,
    /// BSC network latency
    #[metrics(buckets = Buckets::LATENCIES)]
    pub bsc_network_latency: Histogram<Duration>,
    /// Number of BSC reorgs detected
    pub bsc_reorgs_detected: Counter,
    /// BSC confirmation depth used
    pub bsc_confirmation_depth: Gauge<u64>,
    /// Events processed by network type
    pub events_by_network: Family<NetworkType, Counter>,
    /// Block processing latency by network type
    #[metrics(buckets = Buckets::LATENCIES)]
    pub block_processing_by_network: Family<NetworkType, Histogram<Duration>>,
}

#[vise::register]
pub(super) static METRICS: vise::Global<EthWatcherMetrics> = vise::Global::new();
