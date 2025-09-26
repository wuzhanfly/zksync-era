pub mod batch_transaction_fetcher;
pub mod bsc_sync;
mod client;
pub mod data_availability_fetcher;
pub mod external_io;
pub mod fetcher;
pub mod genesis;
mod metrics;
pub mod miniblock_precommit_fetcher;
pub mod node;
pub mod sync_action;
pub mod testonly;
#[cfg(test)]
mod tests;
pub mod transaction_finality_updater;
pub mod tree_data_fetcher;
pub mod validate_chain_ids_task;

pub use self::{
    bsc_sync::{BSCSyncConfig, BSCSyncManager, BSCSyncStatus},
    client::MainNodeClient,
    external_io::ExternalIO,
    sync_action::{ActionQueue, ActionQueueSender},
};

/// Initialize BSC services for node sync
pub fn initialize_bsc_sync(
    client: std::sync::Arc<dyn MainNodeClient>,
    pool: zksync_dal::ConnectionPool<zksync_dal::Core>,
    chain_id: u64,
    action_queue: ActionQueue,
) -> Option<BSCSyncManager> {
    if let Some(config) = BSCSyncConfig::for_chain_id(chain_id) {
        Some(BSCSyncManager::new(client, pool, config, action_queue))
    } else {
        None
    }
}

/// Start BSC services if network is BSC
pub async fn start_bsc_services(chain_id: u64) -> anyhow::Result<()> {
    if BSCSyncConfig::is_bsc_network(chain_id) {
        tracing::info!("Starting BSC sync services for chain_id: {}", chain_id);
        // BSC-specific initialization would go here
        Ok(())
    } else {
        Ok(())
    }
}

/// Validation gas limit used by the external node.
// This config value is used on the main node, and depending on these values certain transactions can
// be *rejected* (that is, not included into the block). However, external node only mirrors what the main
// node has already executed, so we can safely set this value to the maximum possible values – if the main
// node has already executed the transaction, then the external node must execute it too.
const VALIDATION_COMPUTATIONAL_GAS_LIMIT: u32 = u32::MAX;
