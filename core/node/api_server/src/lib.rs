// Everywhere in this module the word "block" actually means "L2 block".

#[macro_use]
mod utils;
pub mod bsc_api;
pub mod execution_sandbox;
pub mod healthcheck;
pub mod node;
#[cfg(test)]
mod testonly;
pub mod tx_sender;
pub mod web3;

/// Initialize BSC API services
pub fn initialize_bsc_api(
    pool: zksync_dal::ConnectionPool<zksync_dal::Core>,
    chain_id: u64,
) -> Option<bsc_api::BSCApiHandler> {
    if let Some(config) = bsc_api::BSCApiConfig::for_chain_id(chain_id) {
        Some(bsc_api::BSCApiHandler::new(pool, config))
    } else {
        None
    }
}

/// Start BSC API services if network is BSC
pub async fn start_bsc_api_services(chain_id: u64) -> anyhow::Result<()> {
    if bsc_api::BSCApiConfig::is_bsc_network(chain_id) {
        tracing::info!("Starting BSC API services for chain_id: {}", chain_id);
        // BSC-specific API initialization would go here
        Ok(())
    } else {
        Ok(())
    }
}
