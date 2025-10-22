//! BSC API 相关命令和工具
//! 
//! 提供 BSC 网络特定的 API 功能，包括：
//! - BSC RPC 端点管理
//! - BSC 区块浏览器 API 集成
//! - BSC 网络状态监控
//! - BSC 特定的 API 优化

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use zkstack_cli_common::{logger, Prompt};
use zkstack_cli_config::{ChainConfig, ZkStackConfig};
use zkstack_cli_types::L1Network;

use crate::messages::{
    MSG_BSC_API_CONFIG_SUCCESS, MSG_BSC_API_SETUP_FINISHED, MSG_BSC_RPC_URL_PROMPT,
    MSG_BSC_SCAN_API_KEY_PROMPT, MSG_CONFIGURING_BSC_API,
};

#[derive(Debug, Parser)]
pub struct BscApiArgs {
    #[command(subcommand)]
    pub command: BscApiCommand,
}

#[derive(Debug, Subcommand)]
pub enum BscApiCommand {
    /// 配置 BSC API 端点和密钥
    #[command(alias = "config")]
    Configure(BscApiConfigureArgs),
    /// 测试 BSC API 连接
    #[command(alias = "test")]
    Test(BscApiTestArgs),
    /// 获取 BSC 网络状态
    #[command(alias = "status")]
    Status(BscApiStatusArgs),
    /// 设置 BSC 区块浏览器集成
    #[command(alias = "explorer")]
    Explorer(BscApiExplorerArgs),
}

#[derive(Debug, Parser)]
pub struct BscApiConfigureArgs {
    /// BSC RPC URL
    #[arg(long)]
    pub rpc_url: Option<String>,
    
    /// BSCScan API 密钥
    #[arg(long)]
    pub bscscan_api_key: Option<String>,
    
    /// 是否为测试网配置
    #[arg(long)]
    pub testnet: bool,
    
    /// 跳过交互式提示
    #[arg(long)]
    pub non_interactive: bool,
}

#[derive(Debug, Parser)]
pub struct BscApiTestArgs {
    /// 要测试的网络
    #[arg(long, default_value = "bsc-mainnet")]
    pub network: String,
    
    /// 详细输出
    #[arg(long)]
    pub verbose: bool,
}

#[derive(Debug, Parser)]
pub struct BscApiStatusArgs {
    /// 要检查的网络
    #[arg(long, default_value = "bsc-mainnet")]
    pub network: String,
    
    /// 输出格式 (json, table)
    #[arg(long, default_value = "table")]
    pub format: String,
}

#[derive(Debug, Parser)]
pub struct BscApiExplorerArgs {
    /// BSCScan API 密钥
    #[arg(long)]
    pub api_key: Option<String>,
    
    /// 是否为测试网配置
    #[arg(long)]
    pub testnet: bool,
}

/// BSC API 配置结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscApiConfig {
    /// BSC Mainnet 配置
    pub mainnet: BscNetworkApiConfig,
    /// BSC Testnet 配置
    pub testnet: BscNetworkApiConfig,
}

/// BSC 网络 API 配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscNetworkApiConfig {
    /// RPC URL
    pub rpc_url: String,
    /// WebSocket URL
    pub ws_url: Option<String>,
    /// BSCScan API 密钥
    pub bscscan_api_key: Option<String>,
    /// BSCScan API URL
    pub bscscan_api_url: String,
    /// 区块浏览器 URL
    pub explorer_url: String,
    /// 是否启用
    pub enabled: bool,
}

impl Default for BscApiConfig {
    fn default() -> Self {
        Self {
            mainnet: BscNetworkApiConfig {
                rpc_url: "https://bsc-dataseed.binance.org/".to_string(),
                ws_url: Some("wss://bsc-ws-node.nariox.org:443/".to_string()),
                bscscan_api_key: None,
                bscscan_api_url: "https://api.bscscan.com/api".to_string(),
                explorer_url: "https://bscscan.com".to_string(),
                enabled: true,
            },
            testnet: BscNetworkApiConfig {
                rpc_url: "https://bsc-testnet-dataseed.bnbchain.org".to_string(),
                ws_url: Some("wss://bsc-testnet-ws-node.nariox.org:443/".to_string()),
                bscscan_api_key: None,
                bscscan_api_url: "https://api-testnet.bscscan.com/api".to_string(),
                explorer_url: "https://testnet.bscscan.com".to_string(),
                enabled: true,
            },
        }
    }
}

/// BSC API 管理器
pub struct BscApiManager {
    config: BscApiConfig,
}

impl BscApiManager {
    /// 创建新的 BSC API 管理器
    pub fn new() -> Self {
        Self {
            config: BscApiConfig::default(),
        }
    }
    
    /// 从配置文件加载
    pub fn load_from_config(chain_config: &ChainConfig) -> Result<Self> {
        // 尝试从链配置中加载 BSC API 配置
        let config_path = chain_config.configs.join("bsc_api.toml");
        
        let config = if config_path.exists() {
            let content = std::fs::read_to_string(&config_path)
                .context("Failed to read BSC API config file")?;
            toml::from_str(&content)
                .context("Failed to parse BSC API config")?
        } else {
            BscApiConfig::default()
        };
        
        Ok(Self { config })
    }
    
    /// 保存配置到文件
    pub fn save_config(&self, chain_config: &ChainConfig) -> Result<()> {
        let config_path = chain_config.configs.join("bsc_api.toml");
        let content = toml::to_string_pretty(&self.config)
            .context("Failed to serialize BSC API config")?;
        
        std::fs::write(&config_path, content)
            .context("Failed to write BSC API config file")?;
        
        Ok(())
    }
    
    /// 获取网络配置
    pub fn get_network_config(&self, testnet: bool) -> &BscNetworkApiConfig {
        if testnet {
            &self.config.testnet
        } else {
            &self.config.mainnet
        }
    }
    
    /// 更新网络配置
    pub fn update_network_config(&mut self, testnet: bool, config: BscNetworkApiConfig) {
        if testnet {
            self.config.testnet = config;
        } else {
            self.config.mainnet = config;
        }
    }
}

/// 执行 BSC API 命令
pub async fn run(args: BscApiArgs) -> Result<()> {
    match args.command {
        BscApiCommand::Configure(args) => configure_bsc_api(args).await,
        BscApiCommand::Test(args) => test_bsc_api(args).await,
        BscApiCommand::Status(args) => get_bsc_api_status(args).await,
        BscApiCommand::Explorer(args) => setup_bsc_explorer(args).await,
    }
}

/// 配置 BSC API
async fn configure_bsc_api(args: BscApiConfigureArgs) -> Result<()> {
    logger::info(MSG_CONFIGURING_BSC_API);
    
    let chain_config = ZkStackConfig::current_chain(&xshell::Shell::new()?)?;
    let mut api_manager = BscApiManager::load_from_config(&chain_config)?;
    
    let network_name = if args.testnet { "BSC Testnet" } else { "BSC Mainnet" };
    println!("🔧 配置 {} API 设置", network_name);
    
    // 获取当前配置
    let current_config = api_manager.get_network_config(args.testnet).clone();
    
    // 获取 RPC URL
    let rpc_url = if let Some(url) = args.rpc_url {
        url
    } else if args.non_interactive {
        current_config.rpc_url
    } else {
        Prompt::new(MSG_BSC_RPC_URL_PROMPT)
            .default(&current_config.rpc_url)
            .ask()
    };
    
    // 获取 BSCScan API 密钥
    let bscscan_api_key = if let Some(key) = args.bscscan_api_key {
        Some(key)
    } else if args.non_interactive {
        current_config.bscscan_api_key
    } else {
        let key = Prompt::new(MSG_BSC_SCAN_API_KEY_PROMPT)
            .default(&current_config.bscscan_api_key.unwrap_or_default())
            .ask();
        if key.is_empty() { None } else { Some(key) }
    };
    
    // 创建新配置
    let new_config = BscNetworkApiConfig {
        rpc_url,
        bscscan_api_key,
        ..current_config
    };
    
    // 更新配置
    api_manager.update_network_config(args.testnet, new_config);
    api_manager.save_config(&chain_config)?;
    
    logger::info(MSG_BSC_API_CONFIG_SUCCESS);
    println!("✅ {} API 配置已更新", network_name);
    
    Ok(())
}

/// 测试 BSC API 连接
async fn test_bsc_api(args: BscApiTestArgs) -> Result<()> {
    let chain_config = ZkStackConfig::current_chain(&xshell::Shell::new()?)?;
    let api_manager = BscApiManager::load_from_config(&chain_config)?;
    
    let testnet = args.network.contains("testnet");
    let network_config = api_manager.get_network_config(testnet);
    
    println!("🧪 测试 {} API 连接...", args.network);
    
    // 测试 RPC 连接
    println!("📡 测试 RPC 连接: {}", network_config.rpc_url);
    match test_rpc_connection(&network_config.rpc_url).await {
        Ok(chain_id) => {
            println!("✅ RPC 连接成功 (Chain ID: {})", chain_id);
        }
        Err(e) => {
            println!("❌ RPC 连接失败: {}", e);
            return Err(e);
        }
    }
    
    // 测试 BSCScan API
    if let Some(api_key) = &network_config.bscscan_api_key {
        println!("🔍 测试 BSCScan API: {}", network_config.bscscan_api_url);
        match test_bscscan_api(&network_config.bscscan_api_url, api_key).await {
            Ok(()) => {
                println!("✅ BSCScan API 连接成功");
            }
            Err(e) => {
                println!("⚠️  BSCScan API 连接失败: {}", e);
                if args.verbose {
                    println!("   这不会影响基本功能，但会限制区块浏览器集成");
                }
            }
        }
    } else {
        println!("ℹ️  未配置 BSCScan API 密钥");
    }
    
    println!("✅ {} API 测试完成", args.network);
    Ok(())
}

/// 获取 BSC API 状态
async fn get_bsc_api_status(args: BscApiStatusArgs) -> Result<()> {
    let chain_config = ZkStackConfig::current_chain(&xshell::Shell::new()?)?;
    let api_manager = BscApiManager::load_from_config(&chain_config)?;
    
    let testnet = args.network.contains("testnet");
    let network_config = api_manager.get_network_config(testnet);
    
    println!("📊 {} API 状态", args.network);
    
    // 获取网络状态
    let status = get_network_status(&network_config.rpc_url).await?;
    
    match args.format.as_str() {
        "json" => {
            let json_output = serde_json::to_string_pretty(&status)?;
            println!("{}", json_output);
        }
        "table" | _ => {
            println!("┌─────────────────────────────────────────┐");
            println!("│ {} 网络状态", args.network.to_uppercase());
            println!("├─────────────────────────────────────────┤");
            println!("│ Chain ID: {:>30} │", status.chain_id);
            println!("│ 最新区块: {:>29} │", status.latest_block);
            println!("│ Gas 价格: {:>26} Gwei │", status.gas_price_gwei);
            println!("│ 区块时间: {:>29} s │", status.block_time);
            println!("│ 网络状态: {:>29} │", if status.is_healthy { "健康" } else { "异常" });
            println!("└─────────────────────────────────────────┘");
        }
    }
    
    Ok(())
}

/// 设置 BSC 区块浏览器集成
async fn setup_bsc_explorer(args: BscApiExplorerArgs) -> Result<()> {
    let chain_config = ZkStackConfig::current_chain(&xshell::Shell::new()?)?;
    let mut api_manager = BscApiManager::load_from_config(&chain_config)?;
    
    let network_name = if args.testnet { "BSC Testnet" } else { "BSC Mainnet" };
    println!("🔍 设置 {} 区块浏览器集成", network_name);
    
    let api_key = if let Some(key) = args.api_key {
        key
    } else {
        Prompt::new("请输入 BSCScan API 密钥:")
            .ask()
    };
    
    // 更新配置
    let mut network_config = api_manager.get_network_config(args.testnet).clone();
    network_config.bscscan_api_key = Some(api_key);
    
    api_manager.update_network_config(args.testnet, network_config);
    api_manager.save_config(&chain_config)?;
    
    println!("✅ {} 区块浏览器集成已配置", network_name);
    logger::info(MSG_BSC_API_SETUP_FINISHED);
    
    Ok(())
}

/// 测试 RPC 连接
async fn test_rpc_connection(rpc_url: &str) -> Result<u64> {
    use reqwest::Client;
    use serde_json::json;
    
    let client = Client::new();
    let response = client
        .post(rpc_url)
        .json(&json!({
            "jsonrpc": "2.0",
            "method": "eth_chainId",
            "params": [],
            "id": 1
        }))
        .send()
        .await
        .context("Failed to send RPC request")?;
    
    let result: serde_json::Value = response
        .json()
        .await
        .context("Failed to parse RPC response")?;
    
    let chain_id_hex = result["result"]
        .as_str()
        .context("Invalid chain ID in response")?;
    
    let chain_id = u64::from_str_radix(chain_id_hex.trim_start_matches("0x"), 16)
        .context("Failed to parse chain ID")?;
    
    Ok(chain_id)
}

/// 测试 BSCScan API
async fn test_bscscan_api(api_url: &str, api_key: &str) -> Result<()> {
    use reqwest::Client;
    
    let client = Client::new();
    let url = format!("{}?module=stats&action=ethsupply&apikey={}", api_url, api_key);
    
    let response = client
        .get(&url)
        .send()
        .await
        .context("Failed to send BSCScan API request")?;
    
    let result: serde_json::Value = response
        .json()
        .await
        .context("Failed to parse BSCScan API response")?;
    
    if result["status"].as_str() != Some("1") {
        return Err(anyhow::anyhow!("BSCScan API returned error: {}", result["message"]));
    }
    
    Ok(())
}

/// 网络状态结构
#[derive(Debug, Serialize, Deserialize)]
struct NetworkStatus {
    chain_id: u64,
    latest_block: u64,
    gas_price_gwei: f64,
    block_time: f64,
    is_healthy: bool,
}

/// 获取网络状态
async fn get_network_status(rpc_url: &str) -> Result<NetworkStatus> {
    use reqwest::Client;
    use serde_json::json;
    
    let client = Client::new();
    
    // 获取链 ID
    let chain_id = test_rpc_connection(rpc_url).await?;
    
    // 获取最新区块
    let response = client
        .post(rpc_url)
        .json(&json!({
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 2
        }))
        .send()
        .await?;
    
    let result: serde_json::Value = response.json().await?;
    let latest_block_hex = result["result"].as_str().unwrap_or("0x0");
    let latest_block = u64::from_str_radix(latest_block_hex.trim_start_matches("0x"), 16)?;
    
    // 获取 Gas 价格
    let response = client
        .post(rpc_url)
        .json(&json!({
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 3
        }))
        .send()
        .await?;
    
    let result: serde_json::Value = response.json().await?;
    let gas_price_hex = result["result"].as_str().unwrap_or("0x0");
    let gas_price_wei = u64::from_str_radix(gas_price_hex.trim_start_matches("0x"), 16)?;
    let gas_price_gwei = gas_price_wei as f64 / 1e9;
    
    Ok(NetworkStatus {
        chain_id,
        latest_block,
        gas_price_gwei,
        block_time: if chain_id == 56 || chain_id == 97 { 3.0 } else { 12.0 },
        is_healthy: true,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bsc_api_config_default() {
        let config = BscApiConfig::default();
        
        // 验证 BSC Mainnet 配置
        assert_eq!(config.mainnet.rpc_url, "https://bsc-dataseed.binance.org/");
        assert_eq!(config.mainnet.explorer_url, "https://bscscan.com");
        assert!(config.mainnet.enabled);
        
        // 验证 BSC Testnet 配置
        assert_eq!(config.testnet.rpc_url, "https://bsc-testnet-dataseed.bnbchain.org");
        assert_eq!(config.testnet.explorer_url, "https://testnet.bscscan.com");
        assert!(config.testnet.enabled);
    }

    #[test]
    fn test_bsc_api_manager() {
        let mut manager = BscApiManager::new();
        
        // 测试获取网络配置
        let mainnet_config = manager.get_network_config(false);
        assert_eq!(mainnet_config.rpc_url, "https://bsc-dataseed.binance.org/");
        
        let testnet_config = manager.get_network_config(true);
        assert_eq!(testnet_config.rpc_url, "https://bsc-testnet-dataseed.bnbchain.org");
        
        // 测试更新配置
        let mut new_config = mainnet_config.clone();
        new_config.bscscan_api_key = Some("test_key".to_string());
        
        manager.update_network_config(false, new_config);
        let updated_config = manager.get_network_config(false);
        assert_eq!(updated_config.bscscan_api_key, Some("test_key".to_string()));
    }
}