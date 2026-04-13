use ethers::{providers::Middleware, types::Address};
use zkstack_cli_common::ethereum::get_ethers_provider;
use zkstack_cli_types::L1Network;

use crate::defaults::bsc;

/// BSC network specific utilities and validations
pub struct BscNetworkUtils;

impl BscNetworkUtils {
    /// Validate BSC network configuration
    pub async fn validate_network_config(
        l1_network: L1Network,
        rpc_url: &str,
    ) -> anyhow::Result<()> {
        if !l1_network.is_bsc_network() {
            return Ok(());
        }

        println!("🔍 Validating BSC network configuration...");

        let provider = get_ethers_provider(rpc_url)?;
        let chain_id = provider.get_chainid().await?.as_u64();

        // Validate chain ID matches expected BSC network
        match (l1_network, chain_id) {
            (L1Network::BscMainnet, 56) => {
                println!("✅ BSC Mainnet configuration validated");
                Self::validate_mainnet_config(&provider).await?;
            }
            (L1Network::BscTestnet, 97) => {
                println!("✅ BSC Testnet configuration validated");
                Self::validate_testnet_config(&provider).await?;
            }
            (L1Network::BscMainnet, _) => {
                anyhow::bail!(
                    "Chain ID mismatch: Expected BSC Mainnet (56), got {}",
                    chain_id
                );
            }
            (L1Network::BscTestnet, _) => {
                anyhow::bail!(
                    "Chain ID mismatch: Expected BSC Testnet (97), got {}",
                    chain_id
                );
            }
            _ => unreachable!("Non-BSC network passed to BSC validator"),
        }

        Ok(())
    }

    /// Validate BSC Mainnet specific configuration
    async fn validate_mainnet_config<M: Middleware + 'static>(provider: &M) -> anyhow::Result<()> {
        println!("🔍 Validating BSC Mainnet specific configuration...");

        // Check WBNB contract exists
        let wbnb_address: Address = bsc::MAINNET_WBNB_ADDRESS.parse()?;
        let wbnb_code = provider.get_code(wbnb_address, None).await?;
        if wbnb_code.is_empty() {
            anyhow::bail!("WBNB contract not found at expected address on BSC Mainnet");
        }
        println!(
            "✅ WBNB contract validated at {}",
            bsc::MAINNET_WBNB_ADDRESS
        );

        // Check Multicall3 contract exists
        let multicall3_address: Address = bsc::MULTICALL3_ADDRESS.parse()?;
        let multicall3_code = provider.get_code(multicall3_address, None).await?;
        if multicall3_code.is_empty() {
            anyhow::bail!("Multicall3 contract not found at expected address on BSC Mainnet");
        }
        println!(
            "✅ Multicall3 contract validated at {}",
            bsc::MULTICALL3_ADDRESS
        );

        // Validate gas price is reasonable for mainnet
        let gas_price = provider.get_gas_price().await?;
        let gas_price_gwei = gas_price.as_u64() / 1_000_000_000;
        if gas_price_gwei > 50 {
            println!("⚠️  Warning: Gas price is high ({} Gwei)", gas_price_gwei);
        } else {
            println!("✅ Gas price is reasonable ({} Gwei)", gas_price_gwei);
        }

        Ok(())
    }

    /// Validate BSC Testnet specific configuration
    async fn validate_testnet_config<M: Middleware + 'static>(provider: &M) -> anyhow::Result<()> {
        println!("🔍 Validating BSC Testnet specific configuration...");

        // Check WBNB contract exists
        let wbnb_address: Address = bsc::TESTNET_WBNB_ADDRESS.parse()?;
        let wbnb_code = provider.get_code(wbnb_address, None).await?;
        if wbnb_code.is_empty() {
            anyhow::bail!("WBNB contract not found at expected address on BSC Testnet");
        }
        println!(
            "✅ WBNB contract validated at {}",
            bsc::TESTNET_WBNB_ADDRESS
        );

        // Check Multicall3 contract exists
        let multicall3_address: Address = bsc::MULTICALL3_ADDRESS.parse()?;
        let multicall3_code = provider.get_code(multicall3_address, None).await?;
        if multicall3_code.is_empty() {
            anyhow::bail!("Multicall3 contract not found at expected address on BSC Testnet");
        }
        println!(
            "✅ Multicall3 contract validated at {}",
            bsc::MULTICALL3_ADDRESS
        );

        println!("💡 Tip: Get testnet BNB from https://testnet.bnbchain.org/faucet-smart");

        Ok(())
    }

    /// Check if wallet has sufficient BNB balance
    pub async fn check_wallet_balance(
        rpc_url: &str,
        wallet_address: Address,
        required_bnb: f64,
    ) -> anyhow::Result<()> {
        let provider = get_ethers_provider(rpc_url)?;
        let balance = provider.get_balance(wallet_address, None).await?;
        let balance_bnb = balance.as_u128() as f64 / 1e18;

        println!("💰 Wallet balance: {:.4} BNB", balance_bnb);

        if balance_bnb < required_bnb {
            anyhow::bail!(
                "Insufficient BNB balance. Required: {:.4} BNB, Available: {:.4} BNB",
                required_bnb,
                balance_bnb
            );
        }

        println!("✅ Sufficient BNB balance for deployment");
        Ok(())
    }
}
