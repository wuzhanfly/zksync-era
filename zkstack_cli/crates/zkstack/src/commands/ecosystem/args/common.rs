use clap::Parser;
use ethers::middleware::Middleware;
use serde::{Deserialize, Serialize};
use url::Url;
use zkstack_cli_common::{ethereum::get_ethers_provider, logger, Prompt};
use zkstack_cli_types::{L1Network, VMOption};

use crate::{
    defaults::LOCAL_RPC_URL,
    messages::{MSG_L1_RPC_URL_HELP, MSG_L1_RPC_URL_INVALID_ERR, MSG_RPC_URL_PROMPT},
};

#[derive(Parser, Debug, Clone, Serialize, Deserialize)]
pub struct CommonEcosystemArgs {
    #[clap(long, default_value_t = false, default_missing_value = "true")]
    pub(crate) zksync_os: bool,
    #[clap(long, default_value_t = true)]
    pub(crate) update_submodules: bool,
    #[clap(long, default_value_t = false, default_missing_value = "true")]
    pub(crate) skip_contract_compilation_override: bool,
    #[clap(long, help = MSG_L1_RPC_URL_HELP)]
    pub(crate) l1_rpc_url: Option<String>,
}

impl CommonEcosystemArgs {
    pub async fn fill_values_with_prompt(
        self,
        l1_network: L1Network,
        dev: bool,
    ) -> anyhow::Result<CommonEcosystemFinalArgs> {
        let l1_rpc_url = self.l1_rpc_url.clone().unwrap_or_else(|| {
            let mut prompt = Prompt::new(MSG_RPC_URL_PROMPT);
            if dev {
                return LOCAL_RPC_URL.to_string();
            }
            if l1_network == L1Network::Localhost {
                prompt = prompt.default(LOCAL_RPC_URL);
            }
            prompt
                .validate_with(|val: &String| -> Result<(), String> {
                    Url::parse(val)
                        .map(|_| ())
                        .map_err(|_| MSG_L1_RPC_URL_INVALID_ERR.to_string())
                })
                .ask()
        });

        check_l1_rpc_health(&l1_rpc_url).await?;

        Ok(CommonEcosystemFinalArgs {
            vm_option: self.vm_option(),
            l1_rpc_url,
        })
    }

    pub fn vm_option(&self) -> VMOption {
        if self.zksync_os {
            VMOption::ZKSyncOsVM
        } else {
            VMOption::EraVM
        }
    }
}

#[derive(Debug, Clone)]
pub struct CommonEcosystemFinalArgs {
    pub(crate) vm_option: VMOption,
    pub(crate) l1_rpc_url: String,
}

/// Check if L1 RPC is healthy by calling eth_chainId
// async fn check_l1_rpc_health(l1_rpc_url: &str) -> anyhow::Result<()> {
//     // Check L1 RPC health after getting the URL
//     logger::info("🔍 Checking L1 RPC health...");
//     let l1_provider = get_ethers_provider(l1_rpc_url)?;
//     let l1_chain_id = l1_provider.get_chainid().await?.as_u64();
//
//     logger::info(format!(
//         "✅ L1 RPC health check passed - chain ID: {}",
//         l1_chain_id
//     ));
//     Ok(())
// }

/// Check if L1 RPC is healthy by calling eth_chainId
async fn check_l1_rpc_health(l1_rpc_url: &str) -> anyhow::Result<()> {
    // Check L1 RPC health after getting the URL
    logger::info("🔍 Checking L1 RPC health...");
    let l1_provider = get_ethers_provider(l1_rpc_url)?;
    let l1_chain_id = l1_provider.get_chainid().await?.as_u64();

    // Validate chain ID matches expected network
    let (network_name, network_type) = match l1_chain_id {
        1 => ("Ethereum Mainnet", "ethereum"),
        9 => ("Localhost", "localhost"),
        56 => ("BSC Mainnet", "bsc"),
        97 => ("BSC Testnet (Chapel)", "bsc"),
        11155111 => ("Sepolia Testnet", "ethereum"),
        17000 => ("Holesky Testnet", "ethereum"),
        _ => ("Unknown Network", "unknown"),
    };

    println!("✅ L1 RPC health check passed - {} (Chain ID: {})", network_name, l1_chain_id);

    // Network-specific validation and optimization
    match network_type {
        "bsc" => {
            println!("🔗 Detected BSC network - ensuring compatibility...");

            // Check if the provider supports BSC-specific features
            let latest_block = l1_provider.get_block_number().await?;
            println!("📦 Latest block number: {}", latest_block);

            // Validate BSC-specific characteristics
            let block = l1_provider.get_block(latest_block).await?;
            if let Some(block) = block {
                let block_time = block.timestamp.as_u64();
                println!("⏰ Latest block timestamp: {}", block_time);
            }

            // BSC has faster block times (~3 seconds vs Ethereum's ~12 seconds)
            if l1_chain_id == 56 {
                println!("⚡ BSC Mainnet detected - optimized for ~3 second block times");
                println!("💰 Native token: BNB");
                println!("🌐 Block explorer: https://bscscan.com");
            } else {
                println!("🧪 BSC Testnet detected - optimized for testing");
                println!("💰 Native token: tBNB (testnet BNB)");
                println!("🌐 Block explorer: https://testnet.bscscan.com");
                println!("🚰 Faucet: https://testnet.bnbchain.org/faucet-smart");
            }

            // Check gas price for BSC networks
            let gas_price = l1_provider.get_gas_price().await?;
            println!("⛽ Current gas price: {} Gwei", gas_price.as_u64() / 1_000_000_000);
        }
        "ethereum" => {
            println!("🔗 Detected Ethereum network");
            if l1_chain_id == 1 {
                println!("⚡ Ethereum Mainnet - ~12 second block times");
            } else {
                println!("🧪 Ethereum Testnet");
            }
        }
        "localhost" => {
            println!("🏠 Detected localhost development network");
        }
        _ => {
            println!("⚠️  Unknown network detected - proceed with caution");
        }
    }

    Ok(())
}

