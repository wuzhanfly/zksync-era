use ethers::types::Address;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub struct BaseToken {
    pub address: Address,
    pub nominator: u64,
    pub denominator: u64,
}

impl BaseToken {
    #[must_use]
    pub fn eth() -> Self {
        Self {
            nominator: 1,
            denominator: 1,
            address: Address::from_low_u64_be(1),
        }
    }

    #[must_use]
    pub fn bnb() -> Self {
        Self {
            nominator: 1,
            denominator: 1,
            address: Address::from_low_u64_be(2), // Different address for BNB
        }
    }

    /// Returns true if this is the ETH base token
    #[must_use]
    pub fn is_eth(&self) -> bool {
        *self == Self::eth()
    }

    /// Returns true if this is the BNB base token
    #[must_use]
    pub fn is_bnb(&self) -> bool {
        *self == Self::bnb()
    }

    /// Returns the symbol for this base token
    #[must_use]
    pub fn symbol(&self) -> &'static str {
        if self.is_eth() {
            "ETH"
        } else if self.is_bnb() {
            "BNB"
        } else {
            "TOKEN"
        }
    }

    /// Returns the default base token for the given L1 network
    #[must_use]
    pub fn default_for_l1_network(l1_network: crate::L1Network) -> Self {
        match l1_network {
            crate::L1Network::Localhost | 
            crate::L1Network::Sepolia | 
            crate::L1Network::Holesky | 
            crate::L1Network::Mainnet => Self::eth(),
            crate::L1Network::BSCMainnet |
            crate::L1Network::BSCTestnet => Self::bnb(),
        }
    }
}
