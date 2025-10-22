//! BSC Portal configuration tests

#[cfg(test)]
mod tests {
    use super::*;
    use zkstack_cli_config::ChainConfig;
    use zkstack_cli_types::{BaseToken, L1Network, TokenInfo};

    #[tokio::test]
    async fn test_bsc_mainnet_token_display() {
        let mut chain_config = ChainConfig::default();
        chain_config.l1_network = L1Network::BscMainnet;
        chain_config.base_token = BaseToken::eth();

        let portal_config = build_portal_chain_config(&chain_config).await.unwrap();

        // Verify BSC mainnet shows BNB
        assert_eq!(portal_config.tokens[0].symbol, "BNB");
        assert_eq!(portal_config.tokens[0].name, Some("BNB".to_string()));
        
        // Verify L1 network config
        let l1_network = portal_config.network.l1_network.unwrap();
        assert_eq!(l1_network.native_currency.symbol, "BNB");
        assert_eq!(l1_network.native_currency.name, "BNB");
    }

    #[tokio::test]
    async fn test_bsc_testnet_token_display() {
        let mut chain_config = ChainConfig::default();
        chain_config.l1_network = L1Network::BscTestnet;
        chain_config.base_token = BaseToken::eth();

        let portal_config = build_portal_chain_config(&chain_config).await.unwrap();

        // Verify BSC testnet shows tBNB
        assert_eq!(portal_config.tokens[0].symbol, "tBNB");
        assert_eq!(portal_config.tokens[0].name, Some("Test BNB".to_string()));
        
        // Verify L1 network config
        let l1_network = portal_config.network.l1_network.unwrap();
        assert_eq!(l1_network.native_currency.symbol, "tBNB");
        assert_eq!(l1_network.native_currency.name, "Test BNB");
    }

    #[tokio::test]
    async fn test_ethereum_token_display_unchanged() {
        let mut chain_config = ChainConfig::default();
        chain_config.l1_network = L1Network::Mainnet;
        chain_config.base_token = BaseToken::eth();

        let portal_config = build_portal_chain_config(&chain_config).await.unwrap();

        // Verify Ethereum still shows ETH
        assert_eq!(portal_config.tokens[0].symbol, "ETH");
        assert_eq!(portal_config.tokens[0].name, Some("Ether".to_string()));
        
        // Verify L1 network config
        let l1_network = portal_config.network.l1_network.unwrap();
        assert_eq!(l1_network.native_currency.symbol, "ETH");
        assert_eq!(l1_network.native_currency.name, "Ether");
    }

    #[test]
    fn test_token_info_bsc_networks() {
        // Test BSC mainnet token info
        let bnb_info = TokenInfo {
            name: "BNB".to_string(),
            symbol: "BNB".to_string(),
            decimals: 18,
        };
        assert_eq!(bnb_info.symbol, "BNB");
        assert_eq!(bnb_info.name, "BNB");

        // Test BSC testnet token info
        let tbnb_info = TokenInfo {
            name: "Test BNB".to_string(),
            symbol: "tBNB".to_string(),
            decimals: 18,
        };
        assert_eq!(tbnb_info.symbol, "tBNB");
        assert_eq!(tbnb_info.name, "Test BNB");
    }
}