use std::{num::NonZeroUsize, time::Duration};

use serde::{Deserialize, Serialize};
use smart_config::{
    de::{Optional, Serde, WellKnown, WellKnownOption},
    DescribeConfig, DeserializeConfig,
};
use zksync_basic_types::{url::SensitiveUrl, Address, L1ChainId, L2ChainId, SLChainId};

/// L1 Network enumeration for different supported networks
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum L1Network {
    #[serde(rename = "localhost")]
    Localhost,
    #[serde(rename = "sepolia")]
    Sepolia,
    #[serde(rename = "holesky")]
    Holesky,
    #[serde(rename = "mainnet")]
    Mainnet,
    #[serde(rename = "bsc-mainnet")]
    BSCMainnet,
    #[serde(rename = "bsc-testnet")]
    BSCTestnet,
}

impl L1Network {
    /// Get the chain ID for the L1 network
    pub fn chain_id(&self) -> L1ChainId {
        match self {
            L1Network::Localhost => L1ChainId(9),
            L1Network::Sepolia => L1ChainId(11_155_111),
            L1Network::Holesky => L1ChainId(17000),
            L1Network::Mainnet => L1ChainId(1),
            L1Network::BSCMainnet => L1ChainId(56),
            L1Network::BSCTestnet => L1ChainId(97),
        }
    }

    /// Get the default RPC URL for the network
    pub fn default_rpc_url(&self) -> &'static str {
        match self {
            L1Network::Localhost => "http://127.0.0.1:8545",
            L1Network::Sepolia => "https://eth-sepolia.g.alchemy.com/v2/demo",
            L1Network::Holesky => "https://eth-holesky.g.alchemy.com/v2/demo",
            L1Network::Mainnet => "https://eth-mainnet.g.alchemy.com/v2/demo",
            L1Network::BSCMainnet => "https://bsc-dataseed1.binance.org",
            L1Network::BSCTestnet => "https://data-seed-prebsc-1-s1.binance.org:8545",
        }
    }

    /// Get the native token symbol for the network
    pub fn native_token_symbol(&self) -> &'static str {
        match self {
            L1Network::Localhost | L1Network::Sepolia | L1Network::Holesky | L1Network::Mainnet => "ETH",
            L1Network::BSCMainnet | L1Network::BSCTestnet => "BNB",
        }
    }

    /// Get the block explorer URL for the network
    pub fn block_explorer_url(&self) -> Option<&'static str> {
        match self {
            L1Network::Localhost => None,
            L1Network::Sepolia => Some("https://sepolia.etherscan.io"),
            L1Network::Holesky => Some("https://holesky.etherscan.io"),
            L1Network::Mainnet => Some("https://etherscan.io"),
            L1Network::BSCMainnet => Some("https://bscscan.com"),
            L1Network::BSCTestnet => Some("https://testnet.bscscan.com"),
        }
    }

    /// Check if the network supports EIP-1559
    pub fn supports_eip1559(&self) -> bool {
        match self {
            L1Network::Localhost | L1Network::Sepolia | L1Network::Holesky | L1Network::Mainnet => true,
            L1Network::BSCMainnet | L1Network::BSCTestnet => false, // BSC doesn't support EIP-1559
        }
    }

    /// Get the recommended gas price in Gwei
    pub fn recommended_gas_price_gwei(&self) -> u64 {
        match self {
            L1Network::Localhost => 1,
            L1Network::Sepolia | L1Network::Holesky => 2,
            L1Network::Mainnet => 20,
            L1Network::BSCMainnet => 5,  // BSC mainnet typical
            L1Network::BSCTestnet => 10, // BSC testnet slightly higher
        }
    }

    /// Get the maximum gas price in Gwei
    pub fn max_gas_price_gwei(&self) -> u64 {
        match self {
            L1Network::Localhost => 10,
            L1Network::Sepolia | L1Network::Holesky => 50,
            L1Network::Mainnet => 200,
            L1Network::BSCMainnet => 20,  // BSC rarely goes above 20 Gwei
            L1Network::BSCTestnet => 50,  // Higher limit for testnet flexibility
        }
    }

    /// Get the average block time in seconds
    pub fn average_block_time_seconds(&self) -> u64 {
        match self {
            L1Network::Localhost => 1,
            L1Network::Sepolia | L1Network::Holesky | L1Network::Mainnet => 12,
            L1Network::BSCMainnet | L1Network::BSCTestnet => 3, // BSC has 3-second block time
        }
    }

    /// Get the gas limit multiplier for safety margin
    pub fn gas_limit_multiplier(&self) -> f64 {
        match self {
            L1Network::Localhost => 1.1,
            L1Network::Sepolia | L1Network::Holesky => 1.2,
            L1Network::Mainnet => 1.3,
            L1Network::BSCMainnet => 1.15, // BSC is more predictable
            L1Network::BSCTestnet => 1.2,
        }
    }

    /// Parse network from string
    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "localhost" => Some(L1Network::Localhost),
            "sepolia" => Some(L1Network::Sepolia),
            "holesky" => Some(L1Network::Holesky),
            "mainnet" => Some(L1Network::Mainnet),
            "bsc-mainnet" => Some(L1Network::BSCMainnet),
            "bsc-testnet" => Some(L1Network::BSCTestnet),
            _ => None,
        }
    }

    /// Convert to string representation
    pub fn as_str(&self) -> &'static str {
        match self {
            L1Network::Localhost => "localhost",
            L1Network::Sepolia => "sepolia",
            L1Network::Holesky => "holesky",
            L1Network::Mainnet => "mainnet",
            L1Network::BSCMainnet => "bsc-mainnet",
            L1Network::BSCTestnet => "bsc-testnet",
        }
    }

    /// Get WETH/WBNB token address for the network
    pub fn wrapped_native_token_address(&self) -> Option<&'static str> {
        match self {
            L1Network::Localhost => None, // No standard WETH on localhost
            L1Network::Sepolia => Some("0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14"), // WETH on Sepolia
            L1Network::Holesky => Some("0x94373a4919B3240D86eA41593D5eBa789FEF3848"), // WETH on Holesky
            L1Network::Mainnet => Some("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"), // WETH on Mainnet
            L1Network::BSCMainnet => Some("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"), // WBNB on BSC Mainnet
            L1Network::BSCTestnet => Some("0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"), // WBNB on BSC Testnet
        }
    }

    /// Get Multicall3 contract address for the network
    pub fn multicall3_address(&self) -> &'static str {
        // Multicall3 is deployed at the same address on most networks
        "0xcA11bde05977b3631167028862bE2a173976CA11"
    }

    /// Get Create2Factory contract address for the network
    pub fn create2_factory_address(&self) -> &'static str {
        // Create2Factory is deployed at the same address on most networks
        "0x4e59b44847b379578588920cA78FbF26c0B4956C"
    }
}

impl WellKnown for L1Network {
    type Deserializer = Serde![str];
    const DE: Self::Deserializer = Serde![str];
}

impl WellKnownOption for L1Network {}

impl std::fmt::Display for L1Network {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

impl std::str::FromStr for L1Network {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::from_str(s).ok_or_else(|| format!("Unknown L1 network: {}", s))
    }
}

/// BSC-specific network configuration
#[derive(Debug, Clone, PartialEq, DescribeConfig, DeserializeConfig)]
pub struct BSCNetworkConfig {
    /// Chain ID of the BSC network
    pub chain_id: u64,
    /// WBNB token address
    pub wbnb_address: String,
    /// Multicall3 contract address
    pub multicall3_address: String,
    /// Create2Factory contract address
    pub create2_factory_address: String,
    /// Recommended gas price in Gwei
    pub recommended_gas_price_gwei: u64,
    /// Maximum gas price in Gwei
    pub max_gas_price_gwei: u64,
    /// Block time in seconds
    pub block_time_seconds: u64,
    /// Whether EIP-1559 is supported (false for BSC)
    pub supports_eip1559: bool,
}

impl BSCNetworkConfig {
    /// Create BSC mainnet configuration
    pub fn mainnet() -> Self {
        Self {
            chain_id: 56,
            wbnb_address: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c".to_string(),
            multicall3_address: "0xcA11bde05977b3631167028862bE2a173976CA11".to_string(),
            create2_factory_address: "0x4e59b44847b379578588920cA78FbF26c0B4956C".to_string(),
            recommended_gas_price_gwei: 5,
            max_gas_price_gwei: 20,
            block_time_seconds: 3,
            supports_eip1559: false,
        }
    }

    /// Create BSC testnet configuration
    pub fn testnet() -> Self {
        Self {
            chain_id: 97,
            wbnb_address: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd".to_string(),
            multicall3_address: "0xcA11bde05977b3631167028862bE2a173976CA11".to_string(),
            create2_factory_address: "0x4e59b44847b379578588920cA78FbF26c0B4956C".to_string(),
            recommended_gas_price_gwei: 10,
            max_gas_price_gwei: 50,
            block_time_seconds: 3,
            supports_eip1559: false,
        }
    }
}

/// L1 contract configuration shared with the main node.
#[derive(Debug, Clone, DescribeConfig, DeserializeConfig)]
#[config(derive(Default))]
pub struct SharedL1ContractsConfig {
    /// Address of the L1 diamond proxy. EN fetches most contract addresses from the L2 peer,
    /// but the diamond proxy address is still available locally as the root of trust.
    pub diamond_proxy_addr: Option<Address>,
}

/// Temporary config for initializing external node, will be completely replaced by consensus config later.
#[derive(Debug, Clone, PartialEq, DescribeConfig, DeserializeConfig)]
pub struct NetworksConfig {
    /// Chain ID of the (L2) network that the node is a part of.
    #[config(with = Serde![int])]
    pub l2_chain_id: L2ChainId,
    /// Chain ID of the L1 network (e.g., Ethereum mainnet).
    #[config(with = Serde![int])]
    pub l1_chain_id: L1ChainId,
    /// Chain ID of the gateway network, if this network settles on one.
    #[config(with = Optional(Serde![int]))]
    pub gateway_chain_id: Option<SLChainId>,
    /// URL of an L2 peer node used to sync from.
    #[config(secret, with = Serde![str])]
    pub main_node_url: SensitiveUrl,
    /// Rate limiting configuration for the L2 peer node.
    #[config(default_t = NonZeroUsize::new(100).unwrap())]
    pub main_node_rate_limit_rps: NonZeroUsize,

    #[config(default_t = Duration::from_secs(60))]
    pub bridge_addresses_refresh_interval: Duration,

    /// L1 network type (optional, can be inferred from l1_chain_id)
    #[config(default)]
    pub l1_network: Option<L1Network>,
}

impl NetworksConfig {
    /// Get the L1 network type, either from explicit config or inferred from chain ID
    pub fn get_l1_network(&self) -> Option<L1Network> {
        if let Some(network) = self.l1_network {
            return Some(network);
        }

        // Infer from chain ID
        match self.l1_chain_id.0 {
            9 => Some(L1Network::Localhost),
            1 => Some(L1Network::Mainnet),
            11_155_111 => Some(L1Network::Sepolia),
            17000 => Some(L1Network::Holesky),
            56 => Some(L1Network::BSCMainnet),
            97 => Some(L1Network::BSCTestnet),
            _ => None,
        }
    }

    /// Check if this is a BSC network
    pub fn is_bsc_network(&self) -> bool {
        matches!(self.get_l1_network(), Some(L1Network::BSCMainnet | L1Network::BSCTestnet))
    }

    /// Get BSC-specific configuration if this is a BSC network
    pub fn get_bsc_config(&self) -> Option<BSCNetworkConfig> {
        match self.get_l1_network()? {
            L1Network::BSCMainnet => Some(BSCNetworkConfig::mainnet()),
            L1Network::BSCTestnet => Some(BSCNetworkConfig::testnet()),
            _ => None,
        }
    }

    /// Create a NetworksConfig for BSC mainnet
    pub fn for_bsc_mainnet(l2_chain_id: L2ChainId, main_node_url: SensitiveUrl) -> Self {
        Self {
            l2_chain_id,
            l1_chain_id: L1ChainId(56),
            gateway_chain_id: None,
            main_node_url,
            main_node_rate_limit_rps: NonZeroUsize::new(100).unwrap(),
            bridge_addresses_refresh_interval: Duration::from_secs(60),
            l1_network: Some(L1Network::BSCMainnet),
        }
    }

    /// Create a NetworksConfig for BSC testnet
    pub fn for_bsc_testnet(l2_chain_id: L2ChainId, main_node_url: SensitiveUrl) -> Self {
        Self {
            l2_chain_id,
            l1_chain_id: L1ChainId(97),
            gateway_chain_id: None,
            main_node_url,
            main_node_rate_limit_rps: NonZeroUsize::new(100).unwrap(),
            bridge_addresses_refresh_interval: Duration::from_secs(60),
            l1_network: Some(L1Network::BSCTestnet),
        }
    }

    pub fn for_tests() -> Self {
        Self {
            l2_chain_id: L2ChainId::default(),
            l1_chain_id: L1ChainId(9),
            main_node_url: "http://localhost:3050/".parse().unwrap(),
            main_node_rate_limit_rps: 100.try_into().unwrap(),
            bridge_addresses_refresh_interval: Duration::from_secs(60),
            gateway_chain_id: None,
            l1_network: Some(L1Network::Localhost),
        }
    }
}

#[cfg(test)]
mod tests {
    use smart_config::{ConfigRepository, ConfigSchema, Environment, Yaml};

    use super::*;

    fn expected_config() -> NetworksConfig {
        NetworksConfig {
            l2_chain_id: L2ChainId::from(271),
            l1_chain_id: L1ChainId(9),
            gateway_chain_id: Some(SLChainId(123)),
            main_node_url: "http://127.0.0.1:3050/".parse().unwrap(),
            main_node_rate_limit_rps: NonZeroUsize::new(200).unwrap(),
            bridge_addresses_refresh_interval: Duration::from_secs(15),
            l1_network: Some(L1Network::Localhost),
        }
    }

    fn create_schema() -> ConfigSchema {
        let mut schema = ConfigSchema::default();
        schema
            .insert(&NetworksConfig::DESCRIPTION, "external_node")
            .unwrap()
            .push_alias("")
            .unwrap();
        schema
    }

    #[test]
    fn parsing_from_env() {
        let env = r#"
            EN_L1_CHAIN_ID=9
            EN_L2_CHAIN_ID=271
            EN_GATEWAY_CHAIN_ID=123
            EN_MAIN_NODE_URL=http://127.0.0.1:3050/
            EN_MAIN_NODE_RATE_LIMIT_RPS=200
            EN_BRIDGE_ADDRESSES_REFRESH_INTERVAL="15s"
        "#;
        let env = Environment::from_dotenv("test.env", env)
            .unwrap()
            .strip_prefix("EN_");

        let schema = create_schema();
        let repo = ConfigRepository::new(&schema).with(env);
        let config: NetworksConfig = repo.single().unwrap().parse().unwrap();
        assert_eq!(config, expected_config());
    }

    #[test]
    fn parsing_from_yaml() {
        let yaml = r#"
            main_node_url: http://127.0.0.1:3050/
            main_node_rate_limit_rps: 200
            gateway_url: null
            l2_chain_id: 271
            l1_chain_id: 9
            gateway_chain_id: 123
            bridge_addresses_refresh_interval: '15s'
        "#;
        let yaml = Yaml::new("test.yml", serde_yaml::from_str(yaml).unwrap()).unwrap();

        let schema = create_schema();
        let repo = ConfigRepository::new(&schema).with(yaml);
        let config: NetworksConfig = repo.single().unwrap().parse().unwrap();
        assert_eq!(config, expected_config());
    }

    #[test]
    fn parsing_from_canonical_yaml() {
        let yaml = r#"
          external_node:
            main_node_url: http://127.0.0.1:3050/
            main_node_rate_limit_rps: 200
            gateway_url: null
            l2_chain_id: 271
            l1_chain_id: 9
            gateway_chain_id: 123
            bridge_addresses_refresh_interval: '15s'
        "#;
        let yaml = Yaml::new("test.yml", serde_yaml::from_str(yaml).unwrap()).unwrap();

        let schema = create_schema();
        let repo = ConfigRepository::new(&schema).with(yaml);
        let config: NetworksConfig = repo.single().unwrap().parse().unwrap();
        assert_eq!(config, expected_config());
    }
}
