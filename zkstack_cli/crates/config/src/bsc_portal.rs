//! BSC Portal 配置扩展
//! 
//! 扩展现有的 Portal 配置以支持 BSC 网络，包括：
//! - BSC 网络特定的 RPC 端点
//! - BSCScan 区块浏览器集成
//! - BNB 代币配置
//! - BSC 特定的网络参数

use serde::{Deserialize, Serialize};
use zkstack_cli_types::{L1Network, TokenInfo};

use crate::portal::{L1NetworkConfig, NetworkConfig, PortalChainConfig, RpcUrlConfig, RpcUrls, TokenConfig};

/// BSC Portal 配置构建器
pub struct BscPortalConfigBuilder;

impl BscPortalConfigBuilder {
    /// 为 BSC Mainnet 创建 Portal 配置
    pub fn create_bsc_mainnet_config(
        chain_id: u64,
        chain_name: &str,
        l2_rpc_url: &str,
        bscscan_api_key: Option<&str>,
    ) -> PortalChainConfig {
        PortalChainConfig {
            network: NetworkConfig {
                id: chain_id,
                key: chain_name.to_string(),
                name: format!("{} (BSC)", chain_name),
                rpc_url: l2_rpc_url.to_string(),
                hidden: Some(false),
                block_explorer_url: Some("https://bscscan.com".to_string()),
                block_explorer_api: bscscan_api_key.map(|key| {
                    format!("https://api.bscscan.com/api?apikey={}", key)
                }),
                public_l1_network_id: Some(56), // BSC Mainnet
                l1_network: Some(Self::create_bsc_mainnet_l1_config()),
                other: serde_json::Value::Null,
            },
            tokens: Self::create_bsc_mainnet_tokens(),
        }
    }
    
    /// 为 BSC Testnet 创建 Portal 配置
    pub fn create_bsc_testnet_config(
        chain_id: u64,
        chain_name: &str,
        l2_rpc_url: &str,
        bscscan_api_key: Option<&str>,
    ) -> PortalChainConfig {
        PortalChainConfig {
            network: NetworkConfig {
                id: chain_id,
                key: chain_name.to_string(),
                name: format!("{} (BSC Testnet)", chain_name),
                rpc_url: l2_rpc_url.to_string(),
                hidden: Some(false),
                block_explorer_url: Some("https://testnet.bscscan.com".to_string()),
                block_explorer_api: bscscan_api_key.map(|key| {
                    format!("https://api-testnet.bscscan.com/api?apikey={}", key)
                }),
                public_l1_network_id: Some(97), // BSC Testnet
                l1_network: Some(Self::create_bsc_testnet_l1_config()),
                other: serde_json::Value::Null,
            },
            tokens: Self::create_bsc_testnet_tokens(),
        }
    }
    
    /// 创建 BSC Mainnet L1 网络配置
    fn create_bsc_mainnet_l1_config() -> L1NetworkConfig {
        L1NetworkConfig {
            id: 56,
            name: "BSC Mainnet".to_string(),
            network: "bsc-mainnet".to_string(),
            native_currency: TokenInfo {
                name: "BNB".to_string(),
                symbol: "BNB".to_string(),
                decimals: 18,
            },
            rpc_urls: RpcUrls {
                default: RpcUrlConfig {
                    http: vec![
                        "https://bsc-dataseed.binance.org/".to_string(),
                        "https://bsc-dataseed1.defibit.io/".to_string(),
                        "https://bsc-dataseed1.ninicoin.io/".to_string(),
                    ],
                },
                public: RpcUrlConfig {
                    http: vec![
                        "https://bsc-dataseed.binance.org/".to_string(),
                        "https://bsc-dataseed2.defibit.io/".to_string(),
                        "https://bsc-dataseed3.defibit.io/".to_string(),
                        "https://bsc-dataseed4.defibit.io/".to_string(),
                    ],
                },
            },
        }
    }
    
    /// 创建 BSC Testnet L1 网络配置
    fn create_bsc_testnet_l1_config() -> L1NetworkConfig {
        L1NetworkConfig {
            id: 97,
            name: "BSC Testnet".to_string(),
            network: "bsc-testnet".to_string(),
            native_currency: TokenInfo {
                name: "tBNB".to_string(),
                symbol: "tBNB".to_string(),
                decimals: 18,
            },
            rpc_urls: RpcUrls {
                default: RpcUrlConfig {
                    http: vec![
                        "https://bsc-testnet-dataseed.bnbchain.org".to_string(),
                        "https://bsc-testnet.public.blastapi.io".to_string(),
                    ],
                },
                public: RpcUrlConfig {
                    http: vec![
                        "https://bsc-testnet-dataseed.bnbchain.org".to_string(),
                        "https://bsc-testnet.public.blastapi.io".to_string(),
                        "https://bsc-testnet-rpc.publicnode.com".to_string(),
                    ],
                },
            },
        }
    }
    
    /// 创建 BSC Mainnet 代币配置
    fn create_bsc_mainnet_tokens() -> Vec<TokenConfig> {
        vec![
            // BNB (原生代币)
            TokenConfig {
                address: "0x0000000000000000000000000000000000000000".to_string(),
                symbol: "BNB".to_string(),
                decimals: 18,
                l1_address: Some("0x0000000000000000000000000000000000000000".to_string()),
                name: Some("BNB".to_string()),
            },
            // WBNB (Wrapped BNB)
            TokenConfig {
                address: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c".to_string(),
                symbol: "WBNB".to_string(),
                decimals: 18,
                l1_address: Some("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c".to_string()),
                name: Some("Wrapped BNB".to_string()),
            },
            // USDT (Tether USD)
            TokenConfig {
                address: "0x55d398326f99059fF775485246999027B3197955".to_string(),
                symbol: "USDT".to_string(),
                decimals: 18,
                l1_address: Some("0x55d398326f99059fF775485246999027B3197955".to_string()),
                name: Some("Tether USD".to_string()),
            },
            // USDC (USD Coin)
            TokenConfig {
                address: "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d".to_string(),
                symbol: "USDC".to_string(),
                decimals: 18,
                l1_address: Some("0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d".to_string()),
                name: Some("USD Coin".to_string()),
            },
        ]
    }
    
    /// 创建 BSC Testnet 代币配置
    fn create_bsc_testnet_tokens() -> Vec<TokenConfig> {
        vec![
            // tBNB (测试网 BNB)
            TokenConfig {
                address: "0x0000000000000000000000000000000000000000".to_string(),
                symbol: "tBNB".to_string(),
                decimals: 18,
                l1_address: Some("0x0000000000000000000000000000000000000000".to_string()),
                name: Some("Test BNB".to_string()),
            },
            // WBNB (测试网 Wrapped BNB)
            TokenConfig {
                address: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd".to_string(),
                symbol: "WBNB".to_string(),
                decimals: 18,
                l1_address: Some("0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd".to_string()),
                name: Some("Wrapped BNB".to_string()),
            },
            // 测试 USDT
            TokenConfig {
                address: "0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684".to_string(),
                symbol: "USDT".to_string(),
                decimals: 18,
                l1_address: Some("0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684".to_string()),
                name: Some("Test Tether USD".to_string()),
            },
        ]
    }
    
    /// 根据 L1 网络类型创建相应的 Portal 配置
    pub fn create_config_for_l1_network(
        l1_network: L1Network,
        chain_id: u64,
        chain_name: &str,
        l2_rpc_url: &str,
        bscscan_api_key: Option<&str>,
    ) -> Option<PortalChainConfig> {
        match l1_network {
            L1Network::BscMainnet => Some(Self::create_bsc_mainnet_config(
                chain_id,
                chain_name,
                l2_rpc_url,
                bscscan_api_key,
            )),
            L1Network::BscTestnet => Some(Self::create_bsc_testnet_config(
                chain_id,
                chain_name,
                l2_rpc_url,
                bscscan_api_key,
            )),
            _ => None, // 非 BSC 网络使用现有逻辑
        }
    }
    
    /// 验证 BSC Portal 配置
    pub fn validate_bsc_config(config: &PortalChainConfig) -> Result<(), String> {
        let network = &config.network;
        
        // 验证 BSC 网络 ID
        if let Some(l1_network_id) = network.public_l1_network_id {
            if !matches!(l1_network_id, 56 | 97) {
                return Err(format!("Invalid BSC network ID: {}", l1_network_id));
            }
        }
        
        // 验证 RPC URL
        if !network.rpc_url.starts_with("http") {
            return Err("Invalid RPC URL format".to_string());
        }
        
        // 验证区块浏览器 URL
        if let Some(explorer_url) = &network.block_explorer_url {
            if !explorer_url.contains("bscscan.com") {
                return Err("BSC networks should use BSCScan explorer".to_string());
            }
        }
        
        // 验证代币配置
        if config.tokens.is_empty() {
            return Err("BSC networks should have at least BNB token configured".to_string());
        }
        
        // 验证 BNB 代币存在
        let has_bnb = config.tokens.iter().any(|token| {
            token.symbol == "BNB" || token.symbol == "tBNB"
        });
        
        if !has_bnb {
            return Err("BSC networks must include BNB token configuration".to_string());
        }
        
        Ok(())
    }
    
    /// 获取 BSC 网络的推荐 RPC 端点
    pub fn get_recommended_rpc_endpoints(testnet: bool) -> Vec<String> {
        if testnet {
            vec![
                "https://bsc-testnet-dataseed.bnbchain.org".to_string(),
                "https://bsc-testnet.public.blastapi.io".to_string(),
                "https://bsc-testnet-rpc.publicnode.com".to_string(),
            ]
        } else {
            vec![
                "https://bsc-dataseed.binance.org/".to_string(),
                "https://bsc-dataseed1.defibit.io/".to_string(),
                "https://bsc-dataseed1.ninicoin.io/".to_string(),
                "https://bsc-dataseed2.defibit.io/".to_string(),
            ]
        }
    }
    
    /// 获取 BSC 网络的区块浏览器信息
    pub fn get_block_explorer_info(testnet: bool) -> (String, String) {
        if testnet {
            (
                "https://testnet.bscscan.com".to_string(),
                "https://api-testnet.bscscan.com/api".to_string(),
            )
        } else {
            (
                "https://bscscan.com".to_string(),
                "https://api.bscscan.com/api".to_string(),
            )
        }
    }
}

/// BSC Portal 配置工具
pub struct BscPortalConfigTool;

impl BscPortalConfigTool {
    /// 更新现有 Portal 配置以支持 BSC
    pub fn update_portal_config_for_bsc(
        portal_config: &mut crate::portal::PortalConfig,
        l1_network: L1Network,
        chain_id: u64,
        chain_name: &str,
        l2_rpc_url: &str,
        bscscan_api_key: Option<&str>,
    ) -> Result<(), String> {
        if !l1_network.is_bsc_network() {
            return Err("Only BSC networks are supported".to_string());
        }
        
        // 创建 BSC 特定的配置
        if let Some(bsc_config) = BscPortalConfigBuilder::create_config_for_l1_network(
            l1_network,
            chain_id,
            chain_name,
            l2_rpc_url,
            bscscan_api_key,
        ) {
            // 验证配置
            BscPortalConfigBuilder::validate_bsc_config(&bsc_config)?;
            
            // 添加到 Portal 配置
            portal_config.add_chain_config(&bsc_config);
            
            println!("✅ BSC Portal 配置已添加: {}", chain_name);
            println!("   网络: {}", l1_network);
            println!("   Chain ID: {}", chain_id);
            println!("   RPC URL: {}", l2_rpc_url);
            
            if bscscan_api_key.is_some() {
                println!("   区块浏览器: 已配置 BSCScan API");
            }
        }
        
        Ok(())
    }
    
    /// 生成 BSC 网络的 Portal JavaScript 配置
    pub fn generate_bsc_portal_js_config(
        portal_config: &crate::portal::PortalConfig,
    ) -> Result<String, String> {
        // 过滤出 BSC 网络配置
        let bsc_chains: Vec<_> = portal_config
            .hyperchains_config
            .iter()
            .filter(|config| {
                config.network.public_l1_network_id
                    .map(|id| matches!(id, 56 | 97))
                    .unwrap_or(false)
            })
            .collect();
        
        if bsc_chains.is_empty() {
            return Err("No BSC chains found in portal configuration".to_string());
        }
        
        // 生成 BSC 特定的配置
        let bsc_config = serde_json::json!({
            "nodeType": "hyperchain",
            "hyperchains": bsc_chains,
            "bscOptimizations": {
                "fastBlockTimes": true,
                "lowGasCosts": true,
                "highThroughput": true,
                "blockTime": 3
            }
        });
        
        let config_js = format!(
            "// BSC 优化的 Portal 配置\nwindow['##runtimeConfig'] = {};",
            serde_json::to_string_pretty(&bsc_config).map_err(|e| e.to_string())?
        );
        
        Ok(config_js)
    }
    
    /// 验证 Portal 配置中的 BSC 网络设置
    pub fn validate_portal_bsc_networks(
        portal_config: &crate::portal::PortalConfig,
    ) -> Result<BscPortalValidationReport, String> {
        let mut report = BscPortalValidationReport::new();
        
        for chain_config in &portal_config.hyperchains_config {
            if let Some(l1_network_id) = chain_config.network.public_l1_network_id {
                if matches!(l1_network_id, 56 | 97) {
                    // 这是一个 BSC 网络，验证其配置
                    match BscPortalConfigBuilder::validate_bsc_config(chain_config) {
                        Ok(()) => {
                            report.add_valid_network(chain_config.network.key.clone());
                        }
                        Err(e) => {
                            report.add_invalid_network(chain_config.network.key.clone(), e);
                        }
                    }
                }
            }
        }
        
        Ok(report)
    }
}

/// BSC Portal 验证报告
#[derive(Debug, Clone)]
pub struct BscPortalValidationReport {
    pub valid_networks: Vec<String>,
    pub invalid_networks: Vec<(String, String)>,
}

impl BscPortalValidationReport {
    fn new() -> Self {
        Self {
            valid_networks: Vec::new(),
            invalid_networks: Vec::new(),
        }
    }
    
    fn add_valid_network(&mut self, network_name: String) {
        self.valid_networks.push(network_name);
    }
    
    fn add_invalid_network(&mut self, network_name: String, error: String) {
        self.invalid_networks.push((network_name, error));
    }
    
    /// 检查是否所有 BSC 网络都有效
    pub fn is_all_valid(&self) -> bool {
        self.invalid_networks.is_empty()
    }
    
    /// 打印验证报告
    pub fn print_summary(&self) {
        println!("🔍 BSC Portal 配置验证报告");
        println!("============================");
        
        if !self.valid_networks.is_empty() {
            println!("\n✅ 有效的 BSC 网络:");
            for network in &self.valid_networks {
                println!("  - {}", network);
            }
        }
        
        if !self.invalid_networks.is_empty() {
            println!("\n❌ 无效的 BSC 网络:");
            for (network, error) in &self.invalid_networks {
                println!("  - {}: {}", network, error);
            }
        }
        
        if self.is_all_valid() {
            println!("\n🎉 所有 BSC 网络配置都有效！");
        } else {
            println!("\n⚠️  发现配置问题，请修复后重试");
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bsc_mainnet_config_creation() {
        let config = BscPortalConfigBuilder::create_bsc_mainnet_config(
            270,
            "test-chain",
            "http://localhost:3050",
            Some("test_api_key"),
        );
        
        assert_eq!(config.network.id, 270);
        assert_eq!(config.network.key, "test-chain");
        assert_eq!(config.network.name, "test-chain (BSC)");
        assert_eq!(config.network.public_l1_network_id, Some(56));
        assert!(config.network.block_explorer_api.is_some());
        
        // 验证 L1 网络配置
        let l1_config = config.network.l1_network.as_ref().unwrap();
        assert_eq!(l1_config.id, 56);
        assert_eq!(l1_config.native_currency.symbol, "BNB");
        
        // 验证代币配置
        assert!(!config.tokens.is_empty());
        assert!(config.tokens.iter().any(|token| token.symbol == "BNB"));
    }

    #[test]
    fn test_bsc_testnet_config_creation() {
        let config = BscPortalConfigBuilder::create_bsc_testnet_config(
            270,
            "test-chain",
            "http://localhost:3050",
            None,
        );
        
        assert_eq!(config.network.public_l1_network_id, Some(97));
        assert!(config.network.block_explorer_api.is_none());
        
        let l1_config = config.network.l1_network.as_ref().unwrap();
        assert_eq!(l1_config.id, 97);
        assert_eq!(l1_config.native_currency.symbol, "tBNB");
        
        // 验证测试网代币
        assert!(config.tokens.iter().any(|token| token.symbol == "tBNB"));
    }

    #[test]
    fn test_bsc_config_validation() {
        let valid_config = BscPortalConfigBuilder::create_bsc_mainnet_config(
            270,
            "test-chain",
            "http://localhost:3050",
            Some("test_key"),
        );
        
        assert!(BscPortalConfigBuilder::validate_bsc_config(&valid_config).is_ok());
        
        // 测试无效配置
        let mut invalid_config = valid_config.clone();
        invalid_config.network.public_l1_network_id = Some(999); // 无效的网络 ID
        
        assert!(BscPortalConfigBuilder::validate_bsc_config(&invalid_config).is_err());
    }

    #[test]
    fn test_recommended_rpc_endpoints() {
        let mainnet_endpoints = BscPortalConfigBuilder::get_recommended_rpc_endpoints(false);
        assert!(!mainnet_endpoints.is_empty());
        assert!(mainnet_endpoints[0].contains("bsc-dataseed"));
        
        let testnet_endpoints = BscPortalConfigBuilder::get_recommended_rpc_endpoints(true);
        assert!(!testnet_endpoints.is_empty());
        assert!(testnet_endpoints[0].contains("testnet"));
    }

    #[test]
    fn test_block_explorer_info() {
        let (mainnet_url, mainnet_api) = BscPortalConfigBuilder::get_block_explorer_info(false);
        assert_eq!(mainnet_url, "https://bscscan.com");
        assert_eq!(mainnet_api, "https://api.bscscan.com/api");
        
        let (testnet_url, testnet_api) = BscPortalConfigBuilder::get_block_explorer_info(true);
        assert_eq!(testnet_url, "https://testnet.bscscan.com");
        assert_eq!(testnet_api, "https://api-testnet.bscscan.com/api");
    }
}