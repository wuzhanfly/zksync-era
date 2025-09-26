use std::time::Duration;

use async_trait::async_trait;
use zksync_config::configs::networks::{L1Network, BSCNetworkConfig};
use zksync_types::{SLChainId, U256};
use zksync_web3_decl::error::{EnrichedClientError, EnrichedClientResult};

use crate::EthInterface;

/// Network validation errors
#[derive(Debug, thiserror::Error)]
pub enum NetworkValidationError {
    #[error("Chain ID mismatch: expected {expected}, got {actual}")]
    ChainIdMismatch { expected: u64, actual: u64 },
    #[error("Gas price too high: {gas_price} exceeds maximum {max_gas_price}")]
    GasPriceTooHigh { gas_price: u64, max_gas_price: u64 },
    #[error("Block time validation failed: expected ~{expected}s, got {actual}s")]
    BlockTimeValidationFailed { expected: u64, actual: u64 },
    #[error("Network feature validation failed: {feature} not supported on {network}")]
    FeatureNotSupported { feature: String, network: String },
    #[error("RPC endpoint validation failed: {reason}")]
    RpcValidationFailed { reason: String },
}

/// Network validator trait for validating L1 network characteristics
#[async_trait]
pub trait NetworkValidator {
    /// Validate that the connected network matches the expected configuration
    async fn validate_network(&self, expected_network: L1Network) -> Result<(), NetworkValidationError>;
    
    /// Validate gas price is within acceptable range for the network
    async fn validate_gas_price(&self, network: L1Network) -> Result<(), NetworkValidationError>;
    
    /// Validate block time characteristics
    async fn validate_block_time(&self, network: L1Network) -> Result<(), NetworkValidationError>;
    
    /// Validate network-specific features (e.g., EIP-1559 support)
    async fn validate_network_features(&self, network: L1Network) -> Result<(), NetworkValidationError>;
}

/// BSC-specific network validator
pub struct BSCNetworkValidator<T: EthInterface> {
    client: T,
}

impl<T: EthInterface> BSCNetworkValidator<T> {
    pub fn new(client: T) -> Self {
        Self { client }
    }
    
    /// Validate BSC-specific network characteristics
    pub async fn validate_bsc_network(&self, expected_chain_id: u64) -> Result<(), NetworkValidationError> {
        // Validate chain ID
        let actual_chain_id = self.client.fetch_chain_id().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch chain ID: {}", e) 
            })?
            .0;
            
        if actual_chain_id != expected_chain_id {
            return Err(NetworkValidationError::ChainIdMismatch {
                expected: expected_chain_id,
                actual: actual_chain_id,
            });
        }
        
        // BSC-specific validations
        if matches!(expected_chain_id, 56 | 97) {
            self.validate_bsc_specific_features(expected_chain_id).await?;
        }
        
        Ok(())
    }
    
    /// Validate BSC-specific features
    async fn validate_bsc_specific_features(&self, chain_id: u64) -> Result<(), NetworkValidationError> {
        let network = match chain_id {
            56 => L1Network::BSCMainnet,
            97 => L1Network::BSCTestnet,
            _ => return Ok(()), // Not a BSC network
        };
        
        // Validate gas price range
        self.validate_bsc_gas_price(network).await?;
        
        // Validate block time (BSC should have ~3 second block times)
        self.validate_bsc_block_time(network).await?;
        
        // Validate that EIP-1559 is not supported (BSC uses legacy transactions)
        self.validate_bsc_transaction_types(network).await?;
        
        Ok(())
    }
    
    /// Validate BSC gas price is within expected range
    async fn validate_bsc_gas_price(&self, network: L1Network) -> Result<(), NetworkValidationError> {
        let gas_price = self.client.get_gas_price().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch gas price: {}", e) 
            })?;
            
        let gas_price_gwei = gas_price.as_u64() / 1_000_000_000;
        let max_gas_price_gwei = network.max_gas_price_gwei();
        
        if gas_price_gwei > max_gas_price_gwei {
            return Err(NetworkValidationError::GasPriceTooHigh {
                gas_price: gas_price_gwei,
                max_gas_price: max_gas_price_gwei,
            });
        }
        
        Ok(())
    }
    
    /// Validate BSC block time characteristics
    async fn validate_bsc_block_time(&self, network: L1Network) -> Result<(), NetworkValidationError> {
        // Get the last few blocks to calculate average block time
        let current_block = self.client.block_number().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch current block: {}", e) 
            })?;
            
        let blocks_to_check = 10u64;
        let start_block = current_block.as_u64().saturating_sub(blocks_to_check);
        
        // Get timestamps for start and end blocks
        let start_block_data = self.client.block(zksync_types::U64::from(start_block).into()).await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch start block: {}", e) 
            })?
            .ok_or_else(|| NetworkValidationError::RpcValidationFailed { 
                reason: "Start block not found".to_string() 
            })?;
            
        let end_block_data = self.client.block(current_block.into()).await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch end block: {}", e) 
            })?
            .ok_or_else(|| NetworkValidationError::RpcValidationFailed { 
                reason: "End block not found".to_string() 
            })?;
            
        let time_diff = end_block_data.timestamp.as_u64() - start_block_data.timestamp.as_u64();
        let avg_block_time = time_diff / blocks_to_check;
        let expected_block_time = network.average_block_time_seconds();
        
        // Allow 50% variance in block time
        let tolerance = expected_block_time / 2;
        if avg_block_time < expected_block_time.saturating_sub(tolerance) || 
           avg_block_time > expected_block_time + tolerance {
            return Err(NetworkValidationError::BlockTimeValidationFailed {
                expected: expected_block_time,
                actual: avg_block_time,
            });
        }
        
        Ok(())
    }
    
    /// Validate BSC transaction type support
    async fn validate_bsc_transaction_types(&self, network: L1Network) -> Result<(), NetworkValidationError> {
        // BSC doesn't support EIP-1559, so we should validate this
        // We can do this by checking if the latest block has a base fee
        let latest_block = self.client.block_number().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch latest block: {}", e) 
            })?;
            
        let block_data = self.client.block(latest_block.into()).await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch block data: {}", e) 
            })?
            .ok_or_else(|| NetworkValidationError::RpcValidationFailed { 
                reason: "Block not found".to_string() 
            })?;
            
        // BSC blocks should not have base_fee_per_gas field
        if !network.supports_eip1559() && block_data.base_fee_per_gas.is_some() {
            return Err(NetworkValidationError::FeatureNotSupported {
                feature: "EIP-1559".to_string(),
                network: network.as_str().to_string(),
            });
        }
        
        Ok(())
    }
}

#[async_trait]
impl<T: EthInterface> NetworkValidator for BSCNetworkValidator<T> {
    async fn validate_network(&self, expected_network: L1Network) -> Result<(), NetworkValidationError> {
        let expected_chain_id = expected_network.chain_id().0;
        self.validate_bsc_network(expected_chain_id).await
    }
    
    async fn validate_gas_price(&self, network: L1Network) -> Result<(), NetworkValidationError> {
        match network {
            L1Network::BSCMainnet | L1Network::BSCTestnet => {
                self.validate_bsc_gas_price(network).await
            }
            _ => Ok(()), // No validation for non-BSC networks
        }
    }
    
    async fn validate_block_time(&self, network: L1Network) -> Result<(), NetworkValidationError> {
        match network {
            L1Network::BSCMainnet | L1Network::BSCTestnet => {
                self.validate_bsc_block_time(network).await
            }
            _ => Ok(()), // No validation for non-BSC networks
        }
    }
    
    async fn validate_network_features(&self, network: L1Network) -> Result<(), NetworkValidationError> {
        match network {
            L1Network::BSCMainnet | L1Network::BSCTestnet => {
                self.validate_bsc_transaction_types(network).await
            }
            _ => Ok(()), // No validation for non-BSC networks
        }
    }
}

/// Utility functions for network validation
pub struct NetworkValidationUtils;

impl NetworkValidationUtils {
    /// Validate RPC endpoint connectivity and basic functionality
    pub async fn validate_rpc_endpoint<T: EthInterface>(
        client: &T,
        expected_network: L1Network,
    ) -> Result<(), NetworkValidationError> {
        // Test basic connectivity
        let _chain_id = client.fetch_chain_id().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("RPC endpoint unreachable: {}", e) 
            })?;
            
        // Test block number fetch
        let _block_number = client.block_number().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch block number: {}", e) 
            })?;
            
        // Test gas price fetch
        let _gas_price = client.get_gas_price().await
            .map_err(|e| NetworkValidationError::RpcValidationFailed { 
                reason: format!("Failed to fetch gas price: {}", e) 
            })?;
            
        Ok(())
    }
    
    /// Get network configuration for a given L1 network
    pub fn get_network_config(network: L1Network) -> Option<BSCNetworkConfig> {
        match network {
            L1Network::BSCMainnet => Some(BSCNetworkConfig::mainnet()),
            L1Network::BSCTestnet => Some(BSCNetworkConfig::testnet()),
            _ => None,
        }
    }
    
    /// Check if a network is a BSC network
    pub fn is_bsc_network(network: L1Network) -> bool {
        matches!(network, L1Network::BSCMainnet | L1Network::BSCTestnet)
    }
    
    /// Get recommended gas price for a network
    pub fn get_recommended_gas_price(network: L1Network) -> u64 {
        network.recommended_gas_price_gwei()
    }
    
    /// Get maximum safe gas price for a network
    pub fn get_max_gas_price(network: L1Network) -> u64 {
        network.max_gas_price_gwei()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use zksync_types::{web3::Block, H256, U64};
    use async_trait::async_trait;
    
    // Mock EthInterface for testing
    struct MockEthInterface {
        chain_id: u64,
        gas_price: u64,
        block_time: u64,
        supports_eip1559: bool,
    }
    
    #[async_trait]
    impl EthInterface for MockEthInterface {
        async fn fetch_chain_id(&self) -> EnrichedClientResult<SLChainId> {
            Ok(SLChainId(self.chain_id))
        }
        
        async fn get_gas_price(&self) -> EnrichedClientResult<U256> {
            Ok(U256::from(self.gas_price * 1_000_000_000)) // Convert Gwei to Wei
        }
        
        async fn block_number(&self) -> EnrichedClientResult<U64> {
            Ok(U64::from(1000))
        }
        
        async fn block(&self, _block_id: zksync_types::web3::BlockId) -> EnrichedClientResult<Option<Block<H256>>> {
            let mut block = Block::default();
            block.timestamp = U256::from(1000000 + self.block_time);
            if !self.supports_eip1559 {
                block.base_fee_per_gas = None;
            } else {
                block.base_fee_per_gas = Some(U256::from(1_000_000_000));
            }
            Ok(Some(block))
        }
        
        // Implement other required methods with defaults
        async fn nonce_at_for_account(&self, _account: zksync_types::Address, _block: zksync_types::web3::BlockNumber) -> EnrichedClientResult<U256> { Ok(U256::zero()) }
        async fn get_pending_block_base_fee_per_gas(&self) -> EnrichedClientResult<U256> { Ok(U256::zero()) }
        async fn send_raw_tx(&self, _tx: crate::RawTransactionBytes) -> EnrichedClientResult<H256> { Ok(H256::zero()) }
        async fn get_tx_status(&self, _hash: H256) -> EnrichedClientResult<Option<crate::ExecutedTxStatus>> { Ok(None) }
        async fn failure_reason(&self, _tx_hash: H256) -> EnrichedClientResult<Option<crate::FailureInfo>> { Ok(None) }
        async fn get_tx(&self, _hash: H256) -> EnrichedClientResult<Option<zksync_types::web3::Transaction>> { Ok(None) }
        async fn tx_receipt(&self, _tx_hash: H256) -> EnrichedClientResult<Option<zksync_types::web3::TransactionReceipt>> { Ok(None) }
        async fn eth_balance(&self, _address: zksync_types::Address) -> EnrichedClientResult<U256> { Ok(U256::zero()) }
        async fn call_contract_function(&self, _request: zksync_types::web3::CallRequest, _block: Option<zksync_types::web3::BlockId>) -> EnrichedClientResult<zksync_types::web3::Bytes> { Ok(zksync_types::web3::Bytes::default()) }
        async fn logs(&self, _filter: &zksync_types::web3::Filter) -> EnrichedClientResult<Vec<zksync_types::web3::Log>> { Ok(vec![]) }
    }
    
    #[tokio::test]
    async fn test_bsc_mainnet_validation() {
        let mock_client = MockEthInterface {
            chain_id: 56,
            gas_price: 5, // 5 Gwei
            block_time: 3, // 3 seconds
            supports_eip1559: false,
        };
        
        let validator = BSCNetworkValidator::new(mock_client);
        let result = validator.validate_network(L1Network::BSCMainnet).await;
        assert!(result.is_ok());
    }
    
    #[tokio::test]
    async fn test_bsc_testnet_validation() {
        let mock_client = MockEthInterface {
            chain_id: 97,
            gas_price: 10, // 10 Gwei
            block_time: 3, // 3 seconds
            supports_eip1559: false,
        };
        
        let validator = BSCNetworkValidator::new(mock_client);
        let result = validator.validate_network(L1Network::BSCTestnet).await;
        assert!(result.is_ok());
    }
    
    #[tokio::test]
    async fn test_chain_id_mismatch() {
        let mock_client = MockEthInterface {
            chain_id: 1, // Ethereum mainnet instead of BSC
            gas_price: 5,
            block_time: 3,
            supports_eip1559: false,
        };
        
        let validator = BSCNetworkValidator::new(mock_client);
        let result = validator.validate_network(L1Network::BSCMainnet).await;
        assert!(result.is_err());
        
        if let Err(NetworkValidationError::ChainIdMismatch { expected, actual }) = result {
            assert_eq!(expected, 56);
            assert_eq!(actual, 1);
        } else {
            panic!("Expected ChainIdMismatch error");
        }
    }
    
    #[tokio::test]
    async fn test_gas_price_too_high() {
        let mock_client = MockEthInterface {
            chain_id: 56,
            gas_price: 25, // 25 Gwei, above BSC mainnet max of 20 Gwei
            block_time: 3,
            supports_eip1559: false,
        };
        
        let validator = BSCNetworkValidator::new(mock_client);
        let result = validator.validate_gas_price(L1Network::BSCMainnet).await;
        assert!(result.is_err());
        
        if let Err(NetworkValidationError::GasPriceTooHigh { gas_price, max_gas_price }) = result {
            assert_eq!(gas_price, 25);
            assert_eq!(max_gas_price, 20);
        } else {
            panic!("Expected GasPriceTooHigh error");
        }
    }
}