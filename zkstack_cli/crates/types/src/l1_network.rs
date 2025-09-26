use std::str::FromStr;

use clap::ValueEnum;
use ethers::types::Address;
use serde::{Deserialize, Serialize};
use strum::EnumIter;

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
    BSCMainnet,
    /// BSC Testnet
    #[clap(name = "bsc-testnet")]
    BSCTestnet,
}

impl L1Network {
    #[must_use]
    pub fn chain_id(&self) -> u64 {
        match self {
            L1Network::Localhost => 9,
            L1Network::Sepolia => 11_155_111,
            L1Network::Holesky => 17000,
            L1Network::Mainnet => 1,
            L1Network::BSCMainnet => 56,
            L1Network::BSCTestnet => 97,
        }
    }

    pub fn avail_l1_da_validator_addr(&self) -> Option<Address> {
        match self {
            L1Network::Localhost => None,
            L1Network::Sepolia | L1Network::Holesky => {
                Some(Address::from_str("0x73d59fe232fce421d1365d6a5beec49acde3d0d9").unwrap())
            }
            L1Network::Mainnet => None, // TODO: add mainnet address after it is known
            L1Network::BSCMainnet => None, // TODO: add BSC mainnet DA validator address
            L1Network::BSCTestnet => None, // TODO: add BSC testnet DA validator address
        }
    }

    /// Returns the default RPC URL for the network
    #[must_use]
    pub fn default_rpc_url(&self) -> Option<&'static str> {
        match self {
            L1Network::Localhost => Some("http://127.0.0.1:8545"),
            L1Network::Sepolia => Some("https://eth-sepolia.g.alchemy.com/v2/demo"),
            L1Network::Holesky => Some("https://eth-holesky.g.alchemy.com/v2/demo"),
            L1Network::Mainnet => Some("https://eth-mainnet.g.alchemy.com/v2/demo"),
            L1Network::BSCMainnet => Some("https://bsc-dataseed1.binance.org"),
            L1Network::BSCTestnet => Some("https://data-seed-prebsc-1-s1.binance.org:8545"),
        }
    }

    /// Returns the native token symbol for the network
    #[must_use]
    pub fn native_token_symbol(&self) -> &'static str {
        match self {
            L1Network::Localhost | L1Network::Sepolia | L1Network::Holesky | L1Network::Mainnet => "ETH",
            L1Network::BSCMainnet | L1Network::BSCTestnet => "BNB",
        }
    }

    /// Returns the block explorer URL for the network
    #[must_use]
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

    /// Returns the recommended gas price in Gwei for the network
    #[must_use]
    pub fn recommended_gas_price_gwei(&self) -> u64 {
        match self {
            L1Network::Localhost => 1, // Low for local testing
            L1Network::Sepolia | L1Network::Holesky => 2, // Testnet rates
            L1Network::Mainnet => 20, // Ethereum mainnet typical
            L1Network::BSCMainnet => 5, // BSC mainnet typical (3-20 range)
            L1Network::BSCTestnet => 10, // BSC testnet (slightly higher for reliability)
        }
    }

    /// Returns the maximum gas price in Gwei for the network
    #[must_use]
    pub fn max_gas_price_gwei(&self) -> u64 {
        match self {
            L1Network::Localhost => 10,
            L1Network::Sepolia | L1Network::Holesky => 50,
            L1Network::Mainnet => 200, // Ethereum can spike very high
            L1Network::BSCMainnet => 20, // BSC rarely goes above 20 Gwei
            L1Network::BSCTestnet => 50, // Higher limit for testnet flexibility
        }
    }

    /// Returns the gas limit multiplier for the network (for safety margin)
    #[must_use]
    pub fn gas_limit_multiplier(&self) -> f64 {
        match self {
            L1Network::Localhost => 1.1, // 10% buffer for local
            L1Network::Sepolia | L1Network::Holesky => 1.2, // 20% buffer for testnets
            L1Network::Mainnet => 1.3, // 30% buffer for mainnet (congestion)
            L1Network::BSCMainnet => 1.15, // 15% buffer (BSC is more predictable)
            L1Network::BSCTestnet => 1.2, // 20% buffer for testnet
        }
    }

    /// Returns the gas limit multiplier as percentage
    #[must_use]
    pub fn gas_limit_multiplier_percent(&self) -> u64 {
        match self {
            L1Network::Localhost => 110, // 10% buffer for local
            L1Network::Sepolia | L1Network::Holesky => 120, // 20% buffer for testnets
            L1Network::Mainnet => 130, // 30% buffer for mainnet (congestion)
            L1Network::BSCMainnet => 115, // 15% buffer (BSC is more predictable)
            L1Network::BSCTestnet => 120, // 20% buffer for testnet
        }
    }

    /// Returns whether the network supports EIP-1559 (London fork)
    #[must_use]
    pub fn supports_eip1559(&self) -> bool {
        match self {
            L1Network::Localhost => true, // Assume modern local setup
            L1Network::Sepolia | L1Network::Holesky | L1Network::Mainnet => true,
            L1Network::BSCMainnet | L1Network::BSCTestnet => false, // BSC doesn't support EIP-1559
        }
    }

    /// Returns the block gas limit for the network
    #[must_use]
    pub fn block_gas_limit(&self) -> u64 {
        match self {
            L1Network::Localhost => 30_000_000, // Similar to Ethereum
            L1Network::Sepolia | L1Network::Holesky => 30_000_000,
            L1Network::Mainnet => 30_000_000,
            L1Network::BSCMainnet => 140_000_000, // BSC has much higher gas limit
            L1Network::BSCTestnet => 140_000_000,
        }
    }

    /// Returns the average block time in seconds
    #[must_use]
    pub fn average_block_time_seconds(&self) -> u64 {
        match self {
            L1Network::Localhost => 1, // Fast for local development
            L1Network::Sepolia | L1Network::Holesky => 12,
            L1Network::Mainnet => 12,
            L1Network::BSCMainnet => 3, // BSC has 3-second block time
            L1Network::BSCTestnet => 3,
        }
    }

    /// Returns gas strategy configuration for the network
    #[must_use]
    pub fn gas_strategy(&self) -> GasStrategy {
        match self {
            L1Network::Localhost => GasStrategy {
                strategy_type: GasStrategyType::Fixed,
                base_gas_price_gwei: 1,
                max_gas_price_gwei: 10,
                gas_limit_multiplier_percent: 110,
                priority_fee_gwei: None,
            },
            L1Network::Sepolia | L1Network::Holesky => GasStrategy {
                strategy_type: GasStrategyType::EIP1559,
                base_gas_price_gwei: 2,
                max_gas_price_gwei: 50,
                gas_limit_multiplier_percent: 120,
                priority_fee_gwei: Some(1),
            },
            L1Network::Mainnet => GasStrategy {
                strategy_type: GasStrategyType::EIP1559,
                base_gas_price_gwei: 20,
                max_gas_price_gwei: 200,
                gas_limit_multiplier_percent: 130,
                priority_fee_gwei: Some(2),
            },
            L1Network::BSCMainnet => GasStrategy {
                strategy_type: GasStrategyType::Legacy,
                base_gas_price_gwei: 5,
                max_gas_price_gwei: 20,
                gas_limit_multiplier_percent: 115,
                priority_fee_gwei: None,
            },
            L1Network::BSCTestnet => GasStrategy {
                strategy_type: GasStrategyType::Legacy,
                base_gas_price_gwei: 10,
                max_gas_price_gwei: 50,
                gas_limit_multiplier_percent: 120,
                priority_fee_gwei: None,
            },
        }
    }
}

/// Gas strategy types for different networks
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum GasStrategyType {
    /// Fixed gas price (for local development)
    Fixed,
    /// Legacy gas pricing (pre-EIP1559)
    Legacy,
    /// EIP-1559 gas pricing with base fee and priority fee
    EIP1559,
}

/// Gas strategy configuration for a network
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct GasStrategy {
    /// The type of gas strategy to use
    pub strategy_type: GasStrategyType,
    /// Base gas price in Gwei
    pub base_gas_price_gwei: u64,
    /// Maximum gas price in Gwei
    pub max_gas_price_gwei: u64,
    /// Gas limit multiplier for safety margin (as percentage, e.g., 115 = 1.15x)
    pub gas_limit_multiplier_percent: u64,
    /// Priority fee in Gwei (for EIP-1559 networks)
    pub priority_fee_gwei: Option<u64>,
}

impl GasStrategy {
    /// Get the gas limit multiplier as a float
    pub fn gas_limit_multiplier(&self) -> f64 {
        self.gas_limit_multiplier_percent as f64 / 100.0
    }
}
