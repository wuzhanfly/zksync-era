pub use self::{
    bsc_state_manager::{BSCStateConfig, BSCStateManager, BSCStateStats},
    io::{
        mempool::MempoolIO, L2BlockParams, L2BlockSealerTask, OutputHandler, StateKeeperIO,
        StateKeeperOutputHandler, StateKeeperPersistence, TreeWritesPersistence,
    },
    keeper::{StateKeeper, StateKeeperBuilder},
    mempool_actor::MempoolFetcher,
    mempool_guard::MempoolGuard,
    seal_criteria::SequencerSealer,
    state_keeper_storage::AsyncRocksdbCache,
    updates::UpdatesManager,
};

pub mod bsc_state_manager;
pub mod executor;
mod health;
pub mod io;
mod keeper;
mod mempool_actor;
pub(crate) mod mempool_guard;
pub mod metrics;
pub mod node;
pub mod seal_criteria;
mod state_keeper_storage;
pub mod testonly;
#[cfg(test)]
pub(crate) mod tests;
pub mod updates;
pub(crate) mod utils;

/// Initialize BSC state manager
pub fn initialize_bsc_state_manager(
    pool: zksync_dal::ConnectionPool<zksync_dal::Core>,
    chain_id: u64,
) -> Option<BSCStateManager> {
    if let Some(config) = BSCStateConfig::for_chain_id(chain_id) {
        Some(BSCStateManager::new(pool, config))
    } else {
        None
    }
}

/// Start BSC state keeper services if network is BSC
pub async fn start_bsc_advanced_state_services(chain_id: u64) -> anyhow::Result<()> {
    if BSCStateConfig::is_bsc_network(chain_id) {
        tracing::info!("Starting BSC advanced state services for chain_id: {}", chain_id);
        // BSC-specific state keeper initialization would go here
        Ok(())
    } else {
        Ok(())
    }
}
