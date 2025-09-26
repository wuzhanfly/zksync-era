use vise::{Counter, Histogram, Metrics};
use zksync_object_store::bincode;
use zksync_prover_interface::inputs::WitnessInputData;

const BYTES_IN_MEGABYTE: u64 = 1024 * 1024;

#[derive(Debug, Metrics)]
pub(super) struct ProofDataHandlerMetrics {
    #[metrics(buckets = vise::Buckets::exponential(1.0..=2_048.0, 2.0))]
    pub vm_run_data_blob_size_in_mb: Histogram<u64>,
    #[metrics(buckets = vise::Buckets::exponential(1.0..=2_048.0, 2.0))]
    pub merkle_paths_blob_size_in_mb: Histogram<u64>,
    #[metrics(buckets = vise::Buckets::exponential(1.0..=2_048.0, 2.0))]
    pub eip_4844_blob_size_in_mb: Histogram<u64>,
    #[metrics(buckets = vise::Buckets::exponential(1.0..=2_048.0, 2.0))]
    pub total_blob_size_in_mb: Histogram<u64>,
    pub fallbacked_batches: Counter<u64>,
}

impl ProofDataHandlerMetrics {
    pub fn observe_blob_sizes(&self, blob: &WitnessInputData) {
        let vm_run_data_blob_size_in_mb =
            bincode::serialize(&blob.vm_run_data).unwrap().len() as u64 / BYTES_IN_MEGABYTE;
        let merkle_paths_blob_size_in_mb =
            bincode::serialize(&blob.merkle_paths).unwrap().len() as u64 / BYTES_IN_MEGABYTE;
        let eip_4844_blob_size_in_mb =
            bincode::serialize(&blob.eip_4844_blobs).unwrap().len() as u64 / BYTES_IN_MEGABYTE;
        let total_blob_size_in_mb =
            bincode::serialize(blob).unwrap().len() as u64 / BYTES_IN_MEGABYTE;

        self.vm_run_data_blob_size_in_mb
            .observe(vm_run_data_blob_size_in_mb);
        self.merkle_paths_blob_size_in_mb
            .observe(merkle_paths_blob_size_in_mb);
        self.eip_4844_blob_size_in_mb
            .observe(eip_4844_blob_size_in_mb);
        self.total_blob_size_in_mb.observe(total_blob_size_in_mb);
    }
}

#[vise::register]
pub(super) static METRICS: vise::Global<ProofDataHandlerMetrics> = vise::Global::new();

/// BSC-specific metrics for proof data handling
#[derive(Debug, Metrics)]
#[metrics(prefix = "bsc_proof_data_handler")]
pub(super) struct BSCProofDataHandlerMetrics {
    /// Number of BSC proofs processed
    pub bsc_proofs_processed: Counter,
    /// BSC proof generation time
    #[metrics(buckets = vise::Buckets::LATENCIES)]
    pub bsc_proof_generation_time: Histogram<std::time::Duration>,
    /// BSC proof compression ratio
    #[metrics(buckets = vise::Buckets::exponential(0.1..=1.0, 1.1))]
    pub bsc_proof_compression_ratio: Histogram<f64>,
    /// BSC proof cache hits
    pub bsc_proof_cache_hits: Counter,
    /// BSC proof batch processing time
    #[metrics(buckets = vise::Buckets::LATENCIES)]
    pub bsc_proof_batch_processing_time: Histogram<std::time::Duration>,
}

#[vise::register]
pub(super) static BSC_PROOF_METRICS: vise::Global<BSCProofDataHandlerMetrics> = vise::Global::new();

/// Combined metrics for easy access
pub(super) struct CombinedMetrics {
    pub proof_handler: &'static ProofDataHandlerMetrics,
    pub bsc_proofs_processed: vise::Counter,
    pub bsc_proof_generation_time: vise::Histogram<std::time::Duration>,
    pub bsc_proof_compression_ratio: vise::Histogram<f64>,
    pub bsc_proof_cache_hits: vise::Counter,
    pub bsc_proof_batch_processing_time: vise::Histogram<std::time::Duration>,
}

pub(super) static COMBINED_METRICS: std::sync::LazyLock<CombinedMetrics> = std::sync::LazyLock::new(|| {
    CombinedMetrics {
        proof_handler: &METRICS,
        bsc_proofs_processed: BSC_PROOF_METRICS.bsc_proofs_processed,
        bsc_proof_generation_time: BSC_PROOF_METRICS.bsc_proof_generation_time,
        bsc_proof_compression_ratio: BSC_PROOF_METRICS.bsc_proof_compression_ratio,
        bsc_proof_cache_hits: BSC_PROOF_METRICS.bsc_proof_cache_hits,
        bsc_proof_batch_processing_time: BSC_PROOF_METRICS.bsc_proof_batch_processing_time,
    }
});

// Re-export for easier access
pub(super) use COMBINED_METRICS as BSC_METRICS;
