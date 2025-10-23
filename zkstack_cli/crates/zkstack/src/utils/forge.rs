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
    // First try URL-based detection for known patterns
    if rpc_url.contains("bsc") || rpc_url.contains("binance") || rpc_url.contains("bnb") {
        if rpc_url.contains("testnet") {
            return Some(zkstack_cli_types::L1Network::BscTestnet);
        } else {
            return Some(zkstack_cli_types::L1Network::BscMainnet);
        }
    } else if rpc_url.contains("127.0.0.1") || rpc_url.contains("localhost") {
        return Some(zkstack_cli_types::L1Network::Localhost);
    } else if rpc_url.contains("sepolia") {
        return Some(zkstack_cli_types::L1Network::Sepolia);
    } else if rpc_url.contains("holesky") {
        return Some(zkstack_cli_types::L1Network::Holesky);
    }
    
    // For unknown URLs, try to detect network by Chain ID
    match get_chain_id_from_rpc(rpc_url) {
        Ok(chain_id) => {
            eprintln!("Successfully detected chain ID: {}", chain_id);
            match chain_id {
                1 => Some(zkstack_cli_types::L1Network::Mainnet),
                56 => Some(zkstack_cli_types::L1Network::BscMainnet),
                97 => {
                    eprintln!("Detected BSC Testnet (Chain ID: 97)");
                    Some(zkstack_cli_types::L1Network::BscTestnet)
                },
                11155111 => Some(zkstack_cli_types::L1Network::Sepolia),
                17000 => Some(zkstack_cli_types::L1Network::Holesky),
                9 => Some(zkstack_cli_types::L1Network::Localhost),
                _ => {
                    eprintln!("Warning: Unknown chain ID: {}, defaulting to Mainnet", chain_id);
                    Some(zkstack_cli_types::L1Network::Mainnet)
                }
            }
        },
        Err(e) => {
            // Fallback to mainnet if chain ID detection fails
            eprintln!("Warning: Failed to detect chain ID from RPC URL: {}, error: {}, defaulting to Mainnet", rpc_url, e);
            Some(zkstack_cli_types::L1Network::Mainnet)
        }
    }
}

/// Get Chain ID from RPC URL by making an eth_chainId call
fn get_chain_id_from_rpc(rpc_url: &str) -> Result<u64, Box<dyn std::error::Error>> {
    use std::process::Command;
    
    // Use curl to make eth_chainId RPC call with timeout
    let output = Command::new("curl")
        .arg("-s")
        .arg("--connect-timeout")
        .arg("10")
        .arg("--max-time")
        .arg("30")
        .arg("-X")
        .arg("POST")
        .arg("-H")
        .arg("Content-Type: application/json")
        .arg("--data")
        .arg(r#"{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}"#)
        .arg(rpc_url)
        .output()?;
    
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("RPC call failed with status: {}, stderr: {}", output.status, stderr);
        return Err(format!("RPC call failed: {}", stderr).into());
    }
    
    let response = String::from_utf8(output.stdout)?;
    eprintln!("RPC response: {}", response);
    
    // Parse JSON response to extract chain ID
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&response) {
        if let Some(result) = json.get("result") {
            if let Some(chain_id_hex) = result.as_str() {
                // Remove "0x" prefix and parse as hex
                let chain_id_str = chain_id_hex.trim_start_matches("0x");
                let chain_id = u64::from_str_radix(chain_id_str, 16)?;
                eprintln!("Detected chain ID: {} (0x{})", chain_id, chain_id_str);
                return Ok(chain_id);
            }
        }
        if let Some(error) = json.get("error") {
            return Err(format!("RPC error: {}", error).into());
        }
    }
    
    Err(format!("Failed to parse chain ID from RPC response: {}", response).into())
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
