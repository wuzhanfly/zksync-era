use clap::Subcommand;
use xshell::Shell;
use zkstack_cli_types::L1Network;

use crate::commands::ecosystem::bsc_utils::BscNetworkUtils;

#[derive(Subcommand, Debug, Clone)]
pub enum BscCommands {
    /// Validate BSC network configuration
    Validate {
        /// BSC network to validate (bsc-mainnet or bsc-testnet)
        #[clap(long)]
        network: L1Network,
        /// RPC URL to validate
        #[clap(long)]
        rpc_url: String,
    },
    /// Show BSC network information
    Info {
        /// BSC network to show info for
        #[clap(long)]
        network: L1Network,
    },
    /// Check wallet balance on BSC
    CheckBalance {
        /// BSC network
        #[clap(long)]
        network: L1Network,
        /// RPC URL
        #[clap(long)]
        rpc_url: String,
        /// Wallet address to check
        #[clap(long)]
        address: String,
    },
    /// Analyze and optimize BSC fees
    AnalyzeFees {
        /// BSC network
        #[clap(long)]
        network: L1Network,
        /// RPC URL
        #[clap(long)]
        rpc_url: String,
        /// Output format: report, json, config
        #[clap(long, default_value = "report")]
        format: String,
    },
    /// Monitor BSC network performance
    Monitor {
        /// BSC network
        #[clap(long)]
        network: L1Network,
        /// RPC URL
        #[clap(long)]
        rpc_url: String,
        /// Monitoring duration in minutes
        #[clap(long, default_value = "10")]
        duration: u64,
        /// Output file for metrics (optional)
        #[clap(long)]
        output: Option<String>,
    },
    /// Generate optimized BSC configuration
    GenerateConfig {
        /// BSC network
        #[clap(long)]
        network: L1Network,
        /// RPC URL
        #[clap(long)]
        rpc_url: String,
        /// Output configuration file
        #[clap(long)]
        output: String,
    },
}

pub async fn run(_shell: &Shell, cmd: BscCommands) -> anyhow::Result<()> {
    match cmd {
        BscCommands::Validate { network, rpc_url } => {
            if !network.is_bsc_network() {
                anyhow::bail!("Only BSC networks are supported for validation");
            }
            BscNetworkUtils::validate_network_config(network, &rpc_url).await?;
            println!("✅ BSC network configuration is valid");
        }

        BscCommands::Info { network } => {
            if !network.is_bsc_network() {
                anyhow::bail!("Only BSC networks are supported");
            }
            show_bsc_info(network);
        }

        BscCommands::CheckBalance {
            network,
            rpc_url,
            address,
        } => {
            if !network.is_bsc_network() {
                anyhow::bail!("Only BSC networks are supported");
            }
            let wallet_address = address.parse()?;
            BscNetworkUtils::check_wallet_balance(&rpc_url, wallet_address, 0.05).await?;
        }

        BscCommands::AnalyzeFees {
            network,
            rpc_url,
            format,
        } => {
            use crate::commands::ecosystem::bsc_fee_calculator::analyze_bsc_fees;
            if !network.is_bsc_network() {
                anyhow::bail!("Only BSC networks are supported for fee analysis");
            }
            analyze_bsc_fees(network, rpc_url, Some(format)).await?;
        }

        BscCommands::Monitor {
            network,
            rpc_url,
            duration,
            output,
        } => {
            use crate::commands::ecosystem::bsc_monitor::BscNetworkMonitor;
            if !network.is_bsc_network() {
                anyhow::bail!("Only BSC networks are supported for monitoring");
            }
            let monitor = BscNetworkMonitor::new(network, rpc_url);
            let metrics = monitor.start_monitoring(duration).await?;

            if let Some(output_file) = output {
                let json_data = serde_json::to_string_pretty(&metrics)?;
                std::fs::write(&output_file, json_data)?;
                println!("📊 Metrics saved to: {}", output_file);
            }

            let report = monitor.generate_performance_report(&metrics);
            println!("\n{}", report);
        }

        BscCommands::GenerateConfig {
            network,
            rpc_url,
            output,
        } => {
            use crate::commands::ecosystem::bsc_fee_calculator::BscFeeCalculator;
            if !network.is_bsc_network() {
                anyhow::bail!("Only BSC networks are supported for config generation");
            }
            let calculator = BscFeeCalculator::new(network, rpc_url);
            let analysis = calculator.analyze_and_optimize().await?;
            let config = calculator.generate_config_updates(&analysis);
            std::fs::write(&output, config)?;
            println!("⚙️  Optimized config generated: {}", output);
        }
    }

    Ok(())
}

fn show_bsc_info(network: L1Network) {
    match network {
        L1Network::BscMainnet => {
            println!("🌐 BSC Mainnet Information");
            println!("Chain ID: 56");
            println!("Native Token: BNB");
            println!("Block Time: ~3 seconds");
            println!("RPC URLs:");
            println!("  - https://bsc-dataseed.binance.org/");
            println!("  - https://bsc-dataseed1.defibit.io/");
            println!("  - https://bsc-dataseed1.ninicoin.io/");
            println!("Block Explorer: https://bscscan.com");
            println!("WBNB Address: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c");
            println!("Multicall3: 0xcA11bde05977b3631167028862bE2a173976CA11");
        }
        L1Network::BscTestnet => {
            println!("🧪 BSC Testnet Information");
            println!("Chain ID: 97");
            println!("Native Token: tBNB");
            println!("Block Time: ~3 seconds");
            println!("RPC URLs:");
            println!("  - https://bsc-testnet-dataseed.bnbchain.org");
            println!("  - https://bsc-testnet.bnbchain.org/");
            println!("  - https://bsc-prebsc-dataseed.bnbchain.org/");
            println!("Block Explorer: https://testnet.bscscan.com");
            println!("Faucet: https://testnet.bnbchain.org/faucet-smart");
            println!("WBNB Address: 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd");
            println!("Multicall3: 0xcA11bde05977b3631167028862bE2a173976CA11");
        }
        _ => {
            println!("❌ Not a BSC network");
        }
    }
}
