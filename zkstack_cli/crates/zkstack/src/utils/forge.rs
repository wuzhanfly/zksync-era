use anyhow::Context as _;
use ethers::types::U256;
use zkstack_cli_common::{forge::ForgeScript, wallets::Wallet};

use crate::{
    consts::MINIMUM_BALANCE_FOR_WALLET,
    messages::{msg_address_doesnt_have_enough_money_prompt_with_network, msg_wallet_private_key_not_set},
};

pub enum WalletOwner {
    Governor,
    Deployer,
}

pub fn fill_forge_private_key(
    mut forge: ForgeScript,
    wallet: Option<&Wallet>,
    wallet_owner: WalletOwner,
) -> anyhow::Result<ForgeScript> {
    if !forge.wallet_args_passed() {
        forge = forge.with_private_key(
            wallet
                .and_then(|w| w.private_key_h256())
                .context(msg_wallet_private_key_not_set(wallet_owner))?,
        );
    }
    Ok(forge)
}

pub async fn check_the_balance(forge: &ForgeScript) -> anyhow::Result<()> {
    // Try to infer network from RPC URL
    let l1_network = if let Some(rpc_url) = forge.rpc_url() {
        infer_l1_network_from_rpc_url(&rpc_url)
    } else {
        None
    };
    check_the_balance_with_network(forge, l1_network).await
}

/// Infer L1 network from RPC URL
fn infer_l1_network_from_rpc_url(rpc_url: &str) -> Option<zkstack_cli_types::L1Network> {
    if rpc_url.contains("bsc") || rpc_url.contains("binance") || rpc_url.contains("bnb") {
        if rpc_url.contains("testnet") {
            Some(zkstack_cli_types::L1Network::BscTestnet)
        } else {
            Some(zkstack_cli_types::L1Network::BscMainnet)
        }
    } else if rpc_url.contains("127.0.0.1") || rpc_url.contains("localhost") {
        Some(zkstack_cli_types::L1Network::Localhost)
    } else if rpc_url.contains("sepolia") {
        Some(zkstack_cli_types::L1Network::Sepolia)
    } else if rpc_url.contains("holesky") {
        Some(zkstack_cli_types::L1Network::Holesky)
    } else {
        // Default to mainnet for unknown URLs
        Some(zkstack_cli_types::L1Network::Mainnet)
    }
}

pub async fn check_the_balance_with_network(forge: &ForgeScript, l1_network: Option<zkstack_cli_types::L1Network>) -> anyhow::Result<()> {
    const MSG_CONTINUE: &str = "Proceed with the deployment anyway";
    const MSG_CHECK_BALANCE: &str = "Check the balance again";
    const MSG_EXIT: &str = "Exit";

    let Some(address) = forge.address() else {
        return Ok(());
    };

    // Use network-specific minimum balance
    let expected_balance = match l1_network {
        Some(zkstack_cli_types::L1Network::BscMainnet) => U256::from(1_00_000_000_000_000_000u128), // 0.1 BNB
        Some(zkstack_cli_types::L1Network::BscTestnet) => U256::from(50_000_000_000_000_000u128), // 0.05 tBNB
        _ => U256::from(MINIMUM_BALANCE_FOR_WALLET), // Default 5 ETH for other networks
    };
    while let Some(balance) = forge.get_the_balance().await? {
        if balance >= expected_balance {
            return Ok(());
        }

        let prompt_msg =
            msg_address_doesnt_have_enough_money_prompt_with_network(&address, balance, expected_balance, l1_network);
        match zkstack_cli_common::PromptSelect::new(
            &prompt_msg,
            [MSG_CONTINUE, MSG_CHECK_BALANCE, MSG_EXIT],
        )
            .ask()
        {
            MSG_CONTINUE => return Ok(()),
            MSG_CHECK_BALANCE => continue,
            MSG_EXIT => anyhow::bail!("Exiting the deployment process"),
            _ => unreachable!(),
        }
    }
    Ok(())
}
