use anyhow::Result;
// use clap::ValueEnum;
use serde::{Deserialize, Serialize};
use zkstack_cli_common::{Prompt, PromptConfirm, PromptSelect};
use zkstack_cli_types::{L1Network, ProverMode, WalletCreation};

// use crate::messages::{
//     MSG_CHAIN_ID_PROMPT, MSG_CHAIN_NAME_PROMPT, MSG_ECOSYSTEM_NAME_PROMPT,
//     MSG_L1_RPC_URL_PROMPT, MSG_PROVER_VERSION_PROMPT, MSG_WALLET_CREATION_PROMPT,
// };

/// BSC配置向导
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BSCWizardConfig {
    pub ecosystem_name: String,
    pub l1_network: L1Network,
    pub chain_name: String,
    pub chain_id: u32,
    pub l1_rpc_url: String,
    pub prover_mode: ProverMode,
    pub wallet_creation: WalletCreation,
    pub wallet_path: Option<String>,
    pub deploy_ecosystem: bool,
    pub deploy_erc20: bool,
    pub deploy_paymaster: bool,
    pub evm_emulator: bool,
    pub observability: bool,
    pub dev_mode: bool,
    pub gas_optimization: BSCGasConfig,
    pub performance_config: BSCPerformanceConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BSCGasConfig {
    pub base_gas_price_gwei: u64,
    pub max_gas_price_gwei: u64,
    pub gas_limit_multiplier_percent: u64,
    pub use_legacy_tx: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BSCPerformanceConfig {
    pub tight_ports: bool,
    pub no_port_reallocation: bool,
    pub start_containers: bool,
    pub update_submodules: bool,
}

impl BSCWizardConfig {
    /// 启动BSC配置向导
    pub fn run_wizard() -> Result<Self> {
        println!("🌟 欢迎使用BSC + ZKsync Era配置向导！");
        println!("此向导将帮助您配置在BSC网络上运行的ZKsync Era L2解决方案。");
        println!();

        // 1. 基本配置
        let basic_config = Self::collect_basic_config()?;
        
        // 2. 网络配置
        let network_config = Self::collect_network_config(&basic_config.l1_network)?;
        
        // 3. Gas优化配置
        let gas_config = Self::collect_gas_config(&basic_config.l1_network)?;
        
        // 4. 性能配置
        let performance_config = Self::collect_performance_config()?;
        
        // 5. 部署配置
        let deployment_config = Self::collect_deployment_config()?;

        Ok(BSCWizardConfig {
            ecosystem_name: basic_config.ecosystem_name,
            l1_network: basic_config.l1_network,
            chain_name: basic_config.chain_name,
            chain_id: basic_config.chain_id,
            l1_rpc_url: network_config.rpc_url,
            prover_mode: basic_config.prover_mode,
            wallet_creation: basic_config.wallet_creation,
            wallet_path: basic_config.wallet_path,
            deploy_ecosystem: deployment_config.deploy_ecosystem,
            deploy_erc20: deployment_config.deploy_erc20,
            deploy_paymaster: deployment_config.deploy_paymaster,
            evm_emulator: deployment_config.evm_emulator,
            observability: deployment_config.observability,
            dev_mode: deployment_config.dev_mode,
            gas_optimization: gas_config,
            performance_config,
        })
    }

    fn collect_basic_config() -> Result<BasicConfig> {
        println!("📋 第1步: 基本配置");
        println!("─────────────────");

        let ecosystem_name = Prompt::new("生态系统名称")
            .default("my-bsc-ecosystem")
            .ask();

        let l1_network = PromptSelect::new(
            "选择BSC网络",
            vec![L1Network::BSCTestnet, L1Network::BSCMainnet],
        )
        .ask();

        let chain_name = Prompt::new("链名称")
            .default(&format!("era-on-{}", 
                if l1_network == L1Network::BSCMainnet { "bsc" } else { "bsc-testnet" }))
            .ask();

        let default_chain_id = match l1_network {
            L1Network::BSCMainnet => 56001,
            L1Network::BSCTestnet => 97001,
            _ => 97001,
        };

        let chain_id = Prompt::new("链ID")
            .default(&default_chain_id.to_string())
            .ask();

        let prover_mode = PromptSelect::new(
            "证明器模式",
            vec![ProverMode::NoProofs, ProverMode::Gpu],
        )
        .ask();

        let wallet_creation = PromptSelect::new(
            "钱包创建方式",
            vec![WalletCreation::Random, WalletCreation::InFile],
        )
        .ask();

        let wallet_path = if wallet_creation == WalletCreation::InFile {
            Some(Prompt::new("钱包文件路径").ask())
        } else {
            None
        };

        Ok(BasicConfig {
            ecosystem_name,
            l1_network,
            chain_name,
            chain_id,
            prover_mode,
            wallet_creation,
            wallet_path,
        })
    }

    fn collect_network_config(l1_network: &L1Network) -> Result<NetworkConfig> {
        println!();
        println!("🌐 第2步: 网络配置");
        println!("─────────────────");

        let default_rpc = l1_network.default_rpc_url().unwrap_or("");
        
        println!("BSC网络信息:");
        println!("  • 链ID: {}", l1_network.chain_id());
        println!("  • 原生代币: {}", l1_network.native_token_symbol());
        println!("  • 区块时间: {}秒", l1_network.average_block_time_seconds());
        println!("  • 区块浏览器: {}", l1_network.block_explorer_url().unwrap_or("N/A"));

        let use_default_rpc = PromptConfirm::new(&format!(
            "使用默认RPC端点? ({})", default_rpc
        ))
        .default(true)
        .ask();

        let rpc_url = if use_default_rpc {
            default_rpc.to_string()
        } else {
            Prompt::new("自定义RPC URL").ask()
        };

        Ok(NetworkConfig { rpc_url })
    }

    fn collect_gas_config(l1_network: &L1Network) -> Result<BSCGasConfig> {
        println!();
        println!("⛽ 第3步: Gas优化配置");
        println!("──────────────────");

        let gas_strategy = l1_network.gas_strategy();
        
        println!("BSC Gas特性:");
        println!("  • 不支持EIP-1559 (使用Legacy交易)");
        println!("  • 推荐Gas价格: {} Gwei", gas_strategy.base_gas_price_gwei);
        println!("  • 最大Gas价格: {} Gwei", gas_strategy.max_gas_price_gwei);
        println!("  • 安全边际: {}%", gas_strategy.gas_limit_multiplier_percent - 100);

        let use_recommended = PromptConfirm::new("使用推荐的Gas配置?")
            .default(true)
            .ask();

        if use_recommended {
            Ok(BSCGasConfig {
                base_gas_price_gwei: gas_strategy.base_gas_price_gwei,
                max_gas_price_gwei: gas_strategy.max_gas_price_gwei,
                gas_limit_multiplier_percent: gas_strategy.gas_limit_multiplier_percent,
                use_legacy_tx: true,
            })
        } else {
            let base_gas_price_gwei = Prompt::new("基础Gas价格 (Gwei)")
                .default(&gas_strategy.base_gas_price_gwei.to_string())
                .ask();

            let max_gas_price_gwei = Prompt::new("最大Gas价格 (Gwei)")
                .default(&gas_strategy.max_gas_price_gwei.to_string())
                .ask();

            let gas_limit_multiplier_percent = Prompt::new("Gas限制安全边际 (%)")
                .default(&(gas_strategy.gas_limit_multiplier_percent - 100).to_string())
                .validate_with(|val: &String| {
                    match val.parse::<u64>() {
                        Ok(v) if v > 0 && v <= 100 => Ok(()),
                        Ok(_) => Err("安全边际应在1-100%之间".to_string()),
                        Err(_) => Err("请输入有效数字".to_string()),
                    }
                })
                .ask::<u64>() + 100;

            Ok(BSCGasConfig {
                base_gas_price_gwei,
                max_gas_price_gwei,
                gas_limit_multiplier_percent,
                use_legacy_tx: true,
            })
        }
    }

    fn collect_performance_config() -> Result<BSCPerformanceConfig> {
        println!();
        println!("🚀 第4步: 性能配置");
        println!("─────────────────");

        println!("BSC性能优势:");
        println!("  • 3秒区块时间 (vs 以太坊12秒)");
        println!("  • 140M Gas限制 (vs 以太坊30M)");
        println!("  • 低延迟交易确认");

        let tight_ports = PromptConfirm::new("使用紧凑端口分配?")
            .default(false)
            .ask();

        let no_port_reallocation = PromptConfirm::new("禁用端口重新分配?")
            .default(false)
            .ask();

        let start_containers = PromptConfirm::new("创建后启动容器?")
            .default(true)
            .ask();

        let update_submodules = PromptConfirm::new("更新Git子模块?")
            .default(true)
            .ask();

        Ok(BSCPerformanceConfig {
            tight_ports,
            no_port_reallocation,
            start_containers,
            update_submodules,
        })
    }

    fn collect_deployment_config() -> Result<DeploymentConfig> {
        println!();
        println!("🏗️ 第5步: 部署配置");
        println!("─────────────────");

        let deploy_ecosystem = PromptConfirm::new("部署生态系统合约?")
            .default(true)
            .ask();

        let deploy_erc20 = PromptConfirm::new("部署ERC20测试代币?")
            .default(true)
            .ask();

        let deploy_paymaster = PromptConfirm::new("部署Paymaster合约?")
            .default(true)
            .ask();

        let evm_emulator = PromptConfirm::new("启用EVM模拟器?")
            .default(true)
            .ask();

        let observability = PromptConfirm::new("启用可观测性?")
            .default(true)
            .ask();

        let dev_mode = PromptConfirm::new("启用开发模式?")
            .default(false)
            .ask();

        Ok(DeploymentConfig {
            deploy_ecosystem,
            deploy_erc20,
            deploy_paymaster,
            evm_emulator,
            observability,
            dev_mode,
        })
    }

    /// 显示配置摘要
    pub fn display_summary(&self) {
        println!();
        println!("📋 配置摘要");
        println!("═══════════");
        println!();
        
        println!("🏗️ 基本信息:");
        println!("  生态系统名称: {}", self.ecosystem_name);
        println!("  L1网络: {:?}", self.l1_network);
        println!("  链名称: {}", self.chain_name);
        println!("  链ID: {}", self.chain_id);
        println!();

        println!("🌐 网络配置:");
        println!("  RPC URL: {}", self.l1_rpc_url);
        println!("  原生代币: BNB");
        println!("  区块浏览器: {}", self.l1_network.block_explorer_url().unwrap_or("N/A"));
        println!();

        println!("⛽ Gas优化:");
        println!("  策略类型: Legacy (BSC不支持EIP-1559)");
        println!("  基础Gas价格: {} Gwei", self.gas_optimization.base_gas_price_gwei);
        println!("  最大Gas价格: {} Gwei", self.gas_optimization.max_gas_price_gwei);
        println!("  安全边际: {}%", self.gas_optimization.gas_limit_multiplier_percent - 100);
        println!();

        println!("🚀 性能配置:");
        println!("  紧凑端口: {}", if self.performance_config.tight_ports { "是" } else { "否" });
        println!("  启动容器: {}", if self.performance_config.start_containers { "是" } else { "否" });
        println!();

        println!("🏗️ 部署选项:");
        println!("  部署生态系统: {}", if self.deploy_ecosystem { "是" } else { "否" });
        println!("  部署ERC20: {}", if self.deploy_erc20 { "是" } else { "否" });
        println!("  部署Paymaster: {}", if self.deploy_paymaster { "是" } else { "否" });
        println!("  EVM模拟器: {}", if self.evm_emulator { "是" } else { "否" });
        println!();

        println!("💰 成本优势 (vs 以太坊):");
        println!("  交易费用: 降低 95%+");
        println!("  部署成本: 降低 90%+");
        println!("  确认时间: 提升 4倍 (3秒 vs 12秒)");
        println!();
    }

    /// 确认配置
    pub fn confirm_config(&self) -> Result<bool> {
        self.display_summary();
        
        Ok(PromptConfirm::new("确认以上配置并继续?")
            .default(true)
            .ask())
    }
}

#[derive(Debug, Clone)]
struct BasicConfig {
    ecosystem_name: String,
    l1_network: L1Network,
    chain_name: String,
    chain_id: u32,
    prover_mode: ProverMode,
    wallet_creation: WalletCreation,
    wallet_path: Option<String>,
}

#[derive(Debug, Clone)]
struct NetworkConfig {
    rpc_url: String,
}

#[derive(Debug, Clone)]
struct DeploymentConfig {
    deploy_ecosystem: bool,
    deploy_erc20: bool,
    deploy_paymaster: bool,
    evm_emulator: bool,
    observability: bool,
    dev_mode: bool,
}