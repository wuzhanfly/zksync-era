pub mod bsc_proof_handler;
mod client;
mod errors;
mod metrics;
pub mod node;
mod processor;
mod proof_router;

pub use crate::{
    bsc_proof_handler::{BSCProofConfig, BSCProofHandler, BSCProofStats},
    errors::ProcessorError,
    processor::*,
};

/// Initialize BSC proof data handler
pub fn initialize_bsc_proof_handler(
    pool: zksync_dal::ConnectionPool<zksync_dal::Core>,
    chain_id: u64,
) -> Option<BSCProofHandler> {
    if let Some(config) = BSCProofConfig::for_chain_id(chain_id) {
        Some(BSCProofHandler::new(pool, config))
    } else {
        None
    }
}

/// Start BSC proof data handler services if network is BSC
pub async fn start_bsc_advanced_proof_services(chain_id: u64) -> anyhow::Result<()> {
    if BSCProofConfig::is_bsc_network(chain_id) {
        tracing::info!("Starting BSC advanced proof services for chain_id: {}", chain_id);
        // BSC-specific proof handler initialization would go here
        Ok(())
    } else {
        Ok(())
    }
}
