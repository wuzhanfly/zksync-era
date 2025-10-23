use std::process::Command;

/// Get Chain ID from RPC URL by making an eth_chainId call
fn get_chain_id_from_rpc(rpc_url: &str) -> Result<u64, Box<dyn std::error::Error>> {
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

fn main() {
    let rpc_url = "http://47.130.24.70:10575";
    
    match get_chain_id_from_rpc(rpc_url) {
        Ok(chain_id) => {
            println!("Successfully detected chain ID: {}", chain_id);
            match chain_id {
                1 => println!("Network: Ethereum Mainnet"),
                56 => println!("Network: BSC Mainnet"),
                97 => println!("Network: BSC Testnet"),
                11155111 => println!("Network: Sepolia"),
                17000 => println!("Network: Holesky"),
                9 => println!("Network: Localhost"),
                _ => println!("Network: Unknown (Chain ID: {})", chain_id),
            }
        },
        Err(e) => {
            eprintln!("Failed to detect chain ID: {}", e);
        }
    }
}