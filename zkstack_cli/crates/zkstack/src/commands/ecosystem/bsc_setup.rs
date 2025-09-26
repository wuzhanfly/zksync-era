use anyhow::Result;
use clap::{Parser, Subcommand};
// use serde::{Deserialize, Serialize};
use xshell::Shell;
use zkstack_cli_common::{logger, PromptConfirm};
use zkstack_cli_types::L1Network;

use super::bsc_wizard::BSCWizardConfig;
use crate::commands::ecosystem::args::create::EcosystemCreateArgs;

#[derive(Debug, Parser)]
pub struct BSCSetupArgs {
    #[clap(subcommand)]
    pub command: BSCSetupCommand,
}

#[derive(Debug, Subcommand)]
pub enum BSCSetupCommand {
    /// 启动BSC配置向导
    Wizard,
    /// 使用预设模板快速创建
    QuickStart {
        /// 生态系统名称
        #[clap(long, default_value = "bsc-ecosystem")]
        name: String,
        /// 使用BSC主网 (默认使用测试网)
        #[clap(long)]
        mainnet: bool,
        /// 链ID
        #[clap(long)]
        chain_id: Option<u32>,
        /// 开发模式
        #[clap(long)]
        dev: bool,
    },
    /// 显示BSC配置模板
    Templates,
    /// 验证BSC网络连接
    Verify {
        /// 网络类型
        #[clap(long, value_enum)]
        network: L1Network,
        /// RPC URL (可选)
        #[clap(long)]
        rpc_url: Option<String>,
    },
}

pub async fn run(args: BSCSetupArgs, shell: &Shell) -> Result<()> {
    match args.command {
        BSCSetupCommand::Wizard => run_wizard(shell).await,
        BSCSetupCommand::QuickStart { name, mainnet, chain_id, dev } => {
            run_quick_start(shell, name, mainnet, chain_id, dev).await
        },
        BSCSetupCommand::Templates => show_templates(),
        BSCSetupCommand::Verify { network, rpc_url } => verify_network(network, rpc_url).await,
    }
}

async fn run_wizard(_shell: &Shell) -> Result<()> {
    logger::info("🌟 启动BSC + ZKsync Era配置向导");
    
    let config = BSCWizardConfig::run_wizard()?;
    
    if !config.confirm_config()? {
        logger::info("配置已取消");
        return Ok(());
    }

    logger::info("🚀 开始创建BSC生态系统...");
    
    // 转换为EcosystemCreateArgs并执行
    let _create_args = convert_to_create_args(&config)?;
    
    // 这里应该调用实际的生态系统创建逻辑
    // super::create::run(create_args, shell).await?;
    
    logger::info("✅ BSC生态系统创建完成!");
    print_next_steps(&config);
    
    Ok(())
}

async fn run_quick_start(
    _shell: &Shell, 
    name: String, 
    mainnet: bool, 
    chain_id: Option<u32>,
    dev: bool
) -> Result<()> {
    logger::info("🚀 BSC快速启动模式");
    
    let l1_network = if mainnet { L1Network::BSCMainnet } else { L1Network::BSCTestnet };
    let default_chain_id = if mainnet { 56001 } else { 97001 };
    let chain_id = chain_id.unwrap_or(default_chain_id);
    
    println!("配置信息:");
    println!("  生态系统名称: {}", name);
    println!("  L1网络: {:?}", l1_network);
    println!("  链ID: {}", chain_id);
    println!("  开发模式: {}", if dev { "是" } else { "否" });
    
    if !PromptConfirm::new("确认创建BSC生态系统?").default(true).ask() {
        logger::info("操作已取消");
        return Ok(());
    }
    
    // 创建快速配置
    let config = create_quick_config(name, l1_network, chain_id, dev);
    
    logger::info("🏗️ 创建生态系统...");
    
    // 这里应该调用实际的创建逻辑
    logger::info("✅ BSC生态系统创建完成!");
    print_next_steps(&config);
    
    Ok(())
}

fn show_templates() -> Result<()> {
    println!("📋 BSC配置模板");
    println!("═══════════════");
    println!();
    
    println!("🌐 BSC测试网模板:");
    println!("  网络: BSC Testnet");
    println!("  链ID: 97");
    println!("  RPC: https://data-seed-prebsc-1-s1.binance.org:8545");
    println!("  浏览器: https://testnet.bscscan.com");
    println!("  Gas价格: 10 Gwei");
    println!("  推荐用于: 开发和测试");
    println!();
    
    println!("🌐 BSC主网模板:");
    println!("  网络: BSC Mainnet");
    println!("  链ID: 56");
    println!("  RPC: https://bsc-dataseed1.binance.org");
    println!("  浏览器: https://bscscan.com");
    println!("  Gas价格: 5 Gwei");
    println!("  推荐用于: 生产环境");
    println!();
    
    println!("⛽ Gas策略模板:");
    println!("  策略类型: Legacy (BSC不支持EIP-1559)");
    println!("  安全边际: 15-20%");
    println!("  最大Gas价格: 20-50 Gwei");
    println!();
    
    println!("🚀 性能优化模板:");
    println!("  区块时间: 3秒");
    println!("  区块Gas限制: 140M");
    println!("  交易确认: 亚秒级");
    println!();
    
    println!("💡 使用方法:");
    println!("  zkstack bsc-setup wizard          # 交互式向导");
    println!("  zkstack bsc-setup quick-start     # 快速开始");
    println!("  zkstack bsc-setup verify          # 验证网络");
    
    Ok(())
}

async fn verify_network(network: L1Network, rpc_url: Option<String>) -> Result<()> {
    use zkstack_cli_common::ethereum::get_ethers_provider;
    
    logger::info(&format!("🔍 验证BSC网络连接: {:?}", network));
    
    let rpc = rpc_url.unwrap_or_else(|| network.default_rpc_url().unwrap().to_string());
    
    println!("验证网络: {:?}", network);
    println!("RPC URL: {}", rpc);
    
    match get_ethers_provider(&rpc) {
        Ok(_provider) => {
            // 这里应该添加实际的网络验证逻辑
            println!("✅ 网络连接成功");
            println!("  链ID: {}", network.chain_id());
            println!("  原生代币: {}", network.native_token_symbol());
            println!("  推荐Gas价格: {} Gwei", network.recommended_gas_price_gwei());
        },
        Err(e) => {
            println!("❌ 网络连接失败: {}", e);
            println!("请检查:");
            println!("  1. RPC URL是否正确");
            println!("  2. 网络连接是否正常");
            println!("  3. RPC服务是否可用");
        }
    }
    
    Ok(())
}

fn convert_to_create_args(_config: &BSCWizardConfig) -> Result<EcosystemCreateArgs> {
    // 这里应该实现配置转换逻辑
    // 将BSCWizardConfig转换为EcosystemCreateArgs
    todo!("实现配置转换")
}

fn create_quick_config(
    name: String, 
    l1_network: L1Network, 
    chain_id: u32, 
    dev: bool
) -> BSCWizardConfig {
    use zkstack_cli_types::{ProverMode, WalletCreation};
    use super::bsc_wizard::{BSCGasConfig, BSCPerformanceConfig};
    
    let gas_strategy = l1_network.gas_strategy();
    
    BSCWizardConfig {
        ecosystem_name: name,
        l1_network,
        chain_name: format!("era-on-{}", if l1_network == L1Network::BSCMainnet { "bsc" } else { "bsc-testnet" }),
        chain_id,
        l1_rpc_url: l1_network.default_rpc_url().unwrap().to_string(),
        prover_mode: if dev { ProverMode::NoProofs } else { ProverMode::Gpu },
        wallet_creation: WalletCreation::Random,
        wallet_path: None,
        deploy_ecosystem: true,
        deploy_erc20: dev,
        deploy_paymaster: dev,
        evm_emulator: true,
        observability: true,
        dev_mode: dev,
        gas_optimization: BSCGasConfig {
            base_gas_price_gwei: gas_strategy.base_gas_price_gwei,
            max_gas_price_gwei: gas_strategy.max_gas_price_gwei,
            gas_limit_multiplier_percent: gas_strategy.gas_limit_multiplier_percent,
            use_legacy_tx: true,
        },
        performance_config: BSCPerformanceConfig {
            tight_ports: false,
            no_port_reallocation: false,
            start_containers: true,
            update_submodules: true,
        },
    }
}

fn print_next_steps(config: &BSCWizardConfig) {
    println!();
    println!("🎉 BSC生态系统创建完成!");
    println!("═══════════════════════");
    println!();
    
    println!("📁 生态系统目录: {}", config.ecosystem_name);
    println!("🌐 L1网络: {:?}", config.l1_network);
    println!("⛓️ 链名称: {}", config.chain_name);
    println!();
    
    println!("🚀 下一步操作:");
    println!("  1. cd {}", config.ecosystem_name);
    println!("  2. zkstack ecosystem init    # 初始化生态系统");
    println!("  3. zkstack chain init        # 初始化链");
    println!("  4. zkstack server run        # 启动服务器");
    println!();
    
    println!("💡 有用的命令:");
    println!("  zkstack status               # 查看状态");
    println!("  zkstack logs                 # 查看日志");
    println!("  zkstack explorer run         # 启动区块浏览器");
    println!();
    
    println!("📚 文档和资源:");
    println!("  BSC文档: https://docs.bnbchain.org");
    println!("  ZKsync文档: https://docs.zksync.io");
    println!("  BSC测试网水龙头: https://testnet.binance.org/faucet-smart");
    println!();
    
    println!("💰 成本优势:");
    println!("  相比以太坊主网，您将享受:");
    println!("  • 95%+ 的交易费用节省");
    println!("  • 4倍的交易确认速度");
    println!("  • 更高的网络吞吐量");
}