use std::str::FromStr;

use clap::ValueEnum;
use ethers::types::Address;
use serde::{Deserialize, Serialize};
use strum::EnumIter;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bsc_mainnet_properties() {
        let network = L1Network::BscMainnet;

        assert_eq!(network.chain_id(), 56);
        assert_eq!(network.native_token_symbol(), "BNB");
        assert!(network.is_bsc_network());
        assert_eq!(network.default_rpc_url(), Some("https://bsc-dataseed.binance.org/"));
        assert_eq!(network.block_explorer_url(), Some("https://bscscan.com"));
    }

    #[test]
    fn test_bsc_testnet_properties() {
        let network = L1Network::BscTestnet;

        assert_eq!(network.chain_id(), 97);
        assert_eq!(network.native_token_symbol(), "BNB");
        assert!(network.is_bsc_network());
        assert_eq!(network.default_rpc_url(), Some("https://bsc-testnet-dataseed.bnbchain.org"));
        assert_eq!(network.block_explorer_url(), Some("https://testnet.bscscan.com"));
    }

    #[test]
    fn test_ethereum_networks_not_bsc() {
        let networks = [
            L1Network::Localhost,
            L1Network::Sepolia,
            L1Network::Holesky,
            L1Network::Mainnet,
        ];

        for network in networks {
            assert!(!network.is_bsc_network());
            assert_eq!(network.native_token_symbol(), "ETH");
        }
    }

    #[test]
    fn test_chain_ids_unique() {
        let networks = [
            L1Network::Localhost,
            L1Network::Sepolia,
            L1Network::Holesky,
            L1Network::Mainnet,
            L1Network::BscMainnet,
            L1Network::BscTestnet,
        ];

        let mut chain_ids = Vec::new();
        for network in networks {
            let chain_id = network.chain_id();
            assert!(!chain_ids.contains(&chain_id), "Duplicate chain ID: {}", chain_id);
            chain_ids.push(chain_id);
        }
    }

    #[test]
    fn test_bsc_network_detection() {
        // Test BSC networks
        assert!(L1Network::BscMainnet.is_bsc_network());
        assert!(L1Network::BscTestnet.is_bsc_network());

        // Test non-BSC networks
        assert!(!L1Network::Localhost.is_bsc_network());
        assert!(!L1Network::Sepolia.is_bsc_network());
        assert!(!L1Network::Holesky.is_bsc_network());
        assert!(!L1Network::Mainnet.is_bsc_network());
    }

    #[test]
    fn test_network_string_representation() {
        assert_eq!(L1Network::BscMainnet.to_string(), "bsc-mainnet");
        assert_eq!(L1Network::BscTestnet.to_string(), "bsc-testnet");
        assert_eq!(L1Network::Mainnet.to_string(), "Mainnet");
        assert_eq!(L1Network::Sepolia.to_string(), "Sepolia");
    }

    #[test]
    fn test_avail_l1_da_validator_addr() {
        // BSC networks should return None for now (TODO items in the code)
        assert_eq!(L1Network::BscMainnet.avail_l1_da_validator_addr(), None);
        assert_eq!(L1Network::BscTestnet.avail_l1_da_validator_addr(), None);

        // Test that Sepolia and Holesky have addresses
        assert!(L1Network::Sepolia.avail_l1_da_validator_addr().is_some());
        assert!(L1Network::Holesky.avail_l1_da_validator_addr().is_some());
    }

    #[test]
    fn test_default_rpc_urls_exist() {
        let networks = [
            L1Network::Localhost,
            L1Network::Sepolia,
            L1Network::Holesky,
            L1Network::Mainnet,
            L1Network::BscMainnet,
            L1Network::BscTestnet,
        ];

        for network in networks {
            let rpc_url = network.default_rpc_url();
            assert!(rpc_url.is_some(), "Network {:?} should have a default RPC URL", network);

            let url = rpc_url.unwrap();
            assert!(!url.is_empty(), "RPC URL should not be empty for {:?}", network);

            // Basic URL format validation
            if network != L1Network::Localhost {
                assert!(url.starts_with("https://"), "RPC URL should use HTTPS for {:?}", network);
            }
        }
    }

    #[test]
    fn test_block_explorer_urls() {
        // BSC networks should have block explorer URLs
        assert!(L1Network::BscMainnet.block_explorer_url().is_some());
        assert!(L1Network::BscTestnet.block_explorer_url().is_some());

        // Localhost should not have a block explorer URL
        assert!(L1Network::Localhost.block_explorer_url().is_none());

        // Other networks should have block explorer URLs
        assert!(L1Network::Mainnet.block_explorer_url().is_some());
        assert!(L1Network::Sepolia.block_explorer_url().is_some());
        assert!(L1Network::Holesky.block_explorer_url().is_some());
    }
}

#[derive(
    Copy,
    Clone,
    Debug,
    Default,
    PartialEq,
    Eq,
    PartialOrd,
    Ord,
    Serialize,
    Deserialize,
    ValueEnum,
    EnumIter,
    strum::Display,
)]
pub enum L1Network {
    #[default]
    Localhost,
    Sepolia,
    Holesky,
    Mainnet,
    /// BSC Mainnet
    #[clap(name = "bsc-mainnet")]
    #[serde(rename = "bsc-mainnet")]
    #[strum(serialize = "bsc-mainnet")]
    BscMainnet,
    /// BSC Testnet (Chapel)
    #[clap(name = "bsc-testnet")]
    #[serde(rename = "bsc-testnet")]
    #[strum(serialize = "bsc-testnet")]
    BscTestnet,
}

impl L1Network {
    #[must_use]
    pub fn chain_id(&self) -> u64 {
        match self {
            L1Network::Localhost => 9,
            L1Network::Sepolia => 11_155_111,
            L1Network::Holesky => 17000,
            L1Network::Mainnet => 1,
            L1Network::BscMainnet => 56,
            L1Network::BscTestnet => 97,
        }
    }

    pub fn avail_l1_da_validator_addr(&self) -> Option<Address> {
        match self {
            L1Network::Localhost => None,
            L1Network::Sepolia | L1Network::Holesky => {
                Some(Address::from_str("0x73d59fe232fce421d1365d6a5beec49acde3d0d9").unwrap())
            }
            L1Network::Mainnet => None, // TODO: add mainnet address after it is known
            L1Network::BscMainnet => None, // TODO: add BSC mainnet DA validator address
            L1Network::BscTestnet => None, // TODO: add BSC testnet DA validator address
        }
    }

    /// Returns the native token symbol for the L1 network
    #[must_use]
    pub fn native_token_symbol(&self) -> &'static str {
        match self {
            L1Network::Localhost | L1Network::Sepolia | L1Network::Holesky | L1Network::Mainnet => "ETH",
            L1Network::BscMainnet | L1Network::BscTestnet => "BNB",
        }
    }

    /// Returns the default RPC URL for the network (for development/testing)
    #[must_use]
    pub fn default_rpc_url(&self) -> Option<&'static str> {
        match self {
            L1Network::Localhost => Some("http://127.0.0.1:8545"),
            L1Network::Sepolia => Some("https://sepolia.infura.io/v3/YOUR_PROJECT_ID"),
            L1Network::Holesky => Some("https://holesky.infura.io/v3/YOUR_PROJECT_ID"),
            L1Network::Mainnet => Some("https://mainnet.infura.io/v3/YOUR_PROJECT_ID"),
            L1Network::BscMainnet => Some("https://bsc-dataseed.binance.org/"),
            L1Network::BscTestnet => Some("https://bsc-testnet-dataseed.bnbchain.org"),
        }
    }

    /// Returns whether this network is a BSC network
    #[must_use]
    pub fn is_bsc_network(&self) -> bool {
        matches!(self, L1Network::BscMainnet | L1Network::BscTestnet)
    }

    /// Returns the block explorer URL for the network
    #[must_use]
    pub fn block_explorer_url(&self) -> Option<&'static str> {
        match self {
            L1Network::Localhost => None,
            L1Network::Sepolia => Some("https://sepolia.etherscan.io"),
            L1Network::Holesky => Some("https://holesky.etherscan.io"),
            L1Network::Mainnet => Some("https://etherscan.io"),
            L1Network::BscMainnet => Some("https://bscscan.com"),
            L1Network::BscTestnet => Some("https://testnet.bscscan.com"),
        }
    }
}
