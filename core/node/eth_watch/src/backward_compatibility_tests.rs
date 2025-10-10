//! 向后兼容性测试套件
//! 
//! 这个测试套件确保 BSC 扩展不会影响现有的 ETH 功能

#[cfg(test)]
mod tests {
    use std::time::Duration;
    use zksync_config::configs::{
        eth_watch::EthWatchConfig,
        network_aware_eth_watch::{NetworkAwareEthWatchConfig, NetworkAwareEthWatchConfigResolver, NetworkType},
    };
    use zksync_types::L1ChainId;

    /// 测试现有 ETH 网络的完全向后兼容性
    #[test]
    fn test_ethereum_networks_backward_compatibility() {
        let ethereum_networks = vec![
            (L1ChainId(1), "Ethereum Mainnet"),
            (L1ChainId(11155111), "Ethereum Sepolia"),
            (L1ChainId(17000), "Ethereum Holesky"),
            (L1ChainId(999), "Unknown Network (should default to Ethereum)"),
        ];

        let base_config = NetworkAwareEthWatchConfig::default();
        let legacy_config = EthWatchConfig::default();

        for (chain_id, network_name) in ethereum_networks {
            // 解析网络感知配置
            let resolved_config = NetworkAwareEthWatchConfigResolver::resolve_config(
                chain_id,
                &base_config,
            );

            // 验证网络类型
            assert_eq!(
                resolved_config.network_type,
                NetworkType::Ethereum,
                "Network {} should be detected as Ethereum",
                network_name
            );

            // 验证向后兼容性
            assert!(
                resolved_config.verify_ethereum_compatibility().is_ok(),
                "Network {} should be backward compatible",
                network_name
            );

            // 转换为遗留配置并比较
            let converted_legacy = resolved_config.to_legacy_config();
            
            assert_eq!(
                converted_legacy.eth_node_poll_interval,
                legacy_config.eth_node_poll_interval,
                "Poll interval should match legacy config for {}",
                network_name
            );
            
            assert_eq!(
                converted_legacy.confirmations_for_eth_event,
                legacy_config.confirmations_for_eth_event,
                "Confirmations should match legacy config for {}",
                network_name
            );
            
            assert_eq!(
                converted_legacy.event_expiration_blocks,
                legacy_config.event_expiration_blocks,
                "Event expiration should match legacy config for {}",
                network_name
            );

            // 验证没有 BSC 优化被应用
            assert!(
                !resolved_config.enable_aggressive_batching,
                "Ethereum networks should not have aggressive batching enabled"
            );
            assert!(
                !resolved_config.fast_confirmation_mode,
                "Ethereum networks should not have fast confirmation mode enabled"
            );
            assert_eq!(
                resolved_config.parallel_batch_workers,
                1,
                "Ethereum networks should use single worker"
            );
        }
    }

    /// 测试 BSC 网络获得正确的优化
    #[test]
    fn test_bsc_networks_get_optimizations() {
        let bsc_networks = vec![
            (L1ChainId(56), "BSC Mainnet"),
            (L1ChainId(97), "BSC Testnet"),
        ];

        let base_config = NetworkAwareEthWatchConfig::default();

        for (chain_id, network_name) in bsc_networks {
            let resolved_config = NetworkAwareEthWatchConfigResolver::resolve_config(
                chain_id,
                &base_config,
            );

            // 验证网络类型
            assert_eq!(
                resolved_config.network_type,
                NetworkType::Bsc,
                "Network {} should be detected as BSC",
                network_name
            );

            // 验证 BSC 优化已启用
            assert!(
                resolved_config.enable_aggressive_batching,
                "BSC networks should have aggressive batching enabled"
            );
            assert!(
                resolved_config.fast_confirmation_mode,
                "BSC networks should have fast confirmation mode enabled"
            );
            assert!(
                resolved_config.parallel_batch_workers > 1,
                "BSC networks should use multiple workers"
            );

            // 验证 BSC 特定的配置值
            assert_eq!(
                resolved_config.eth_node_poll_interval,
                Duration::from_millis(1500),
                "BSC should use 1.5 second polling interval"
            );
            assert_eq!(
                resolved_config.confirmations_for_eth_event,
                Some(2),
                "BSC should use 2 confirmations"
            );
            assert_eq!(
                resolved_config.event_expiration_blocks,
                150_000,
                "BSC should use extended event expiration"
            );
        }
    }

    /// 测试配置隔离 - BSC 配置不影响 ETH 配置
    #[test]
    fn test_configuration_isolation() {
        let base_config = NetworkAwareEthWatchConfig::default();

        // 获取 ETH 和 BSC 配置
        let eth_config = NetworkAwareEthWatchConfigResolver::resolve_config(
            L1ChainId(1),
            &base_config,
        );
        let bsc_config = NetworkAwareEthWatchConfigResolver::resolve_config(
            L1ChainId(56),
            &base_config,
        );

        // 验证配置完全不同
        assert_ne!(eth_config.network_type, bsc_config.network_type);
        assert_ne!(eth_config.eth_node_poll_interval, bsc_config.eth_node_poll_interval);
        assert_ne!(eth_config.confirmations_for_eth_event, bsc_config.confirmations_for_eth_event);
        assert_ne!(eth_config.event_expiration_blocks, bsc_config.event_expiration_blocks);
        assert_ne!(eth_config.enable_aggressive_batching, bsc_config.enable_aggressive_batching);
        assert_ne!(eth_config.fast_confirmation_mode, bsc_config.fast_confirmation_mode);
        assert_ne!(eth_config.parallel_batch_workers, bsc_config.parallel_batch_workers);

        // 验证 ETH 配置仍然是标准的
        assert_eq!(eth_config.network_type, NetworkType::Ethereum);
        assert!(!eth_config.enable_aggressive_batching);
        assert!(!eth_config.fast_confirmation_mode);
        assert_eq!(eth_config.parallel_batch_workers, 1);
    }

    /// 测试默认配置值的一致性
    #[test]
    fn test_default_config_consistency() {
        let network_aware_config = NetworkAwareEthWatchConfig::default();
        let legacy_config = EthWatchConfig::default();

        // 验证以太坊配置与遗留配置匹配
        assert_eq!(
            network_aware_config.ethereum.eth_node_poll_interval,
            legacy_config.eth_node_poll_interval
        );
        assert_eq!(
            network_aware_config.ethereum.confirmations_for_eth_event,
            legacy_config.confirmations_for_eth_event
        );
        assert_eq!(
            network_aware_config.ethereum.event_expiration_blocks,
            legacy_config.event_expiration_blocks
        );
    }

    /// 测试网络检测逻辑的准确性
    #[test]
    fn test_network_detection_accuracy() {
        // 测试所有已知的网络 ID
        let test_cases = vec![
            (1, NetworkType::Ethereum, "Ethereum Mainnet"),
            (11155111, NetworkType::Ethereum, "Ethereum Sepolia"),
            (17000, NetworkType::Ethereum, "Ethereum Holesky"),
            (56, NetworkType::Bsc, "BSC Mainnet"),
            (97, NetworkType::Bsc, "BSC Testnet"),
            (137, NetworkType::Ethereum, "Polygon (should default to Ethereum)"),
            (43114, NetworkType::Ethereum, "Avalanche (should default to Ethereum)"),
            (999999, NetworkType::Ethereum, "Unknown network (should default to Ethereum)"),
        ];

        for (chain_id, expected_type, description) in test_cases {
            let detected_type = NetworkAwareEthWatchConfigResolver::detect_network_type(
                L1ChainId(chain_id)
            );
            assert_eq!(
                detected_type,
                expected_type,
                "Chain ID {} ({}) should be detected as {:?}",
                chain_id,
                description,
                expected_type
            );
        }
    }

    /// 测试配置转换的无损性
    #[test]
    fn test_config_conversion_lossless() {
        let base_config = NetworkAwareEthWatchConfig::default();
        
        // 测试以太坊网络的配置转换
        let eth_config = NetworkAwareEthWatchConfigResolver::resolve_config(
            L1ChainId(1),
            &base_config,
        );
        
        let legacy_config = eth_config.to_legacy_config();
        
        // 验证转换是无损的
        assert_eq!(legacy_config.eth_node_poll_interval, eth_config.eth_node_poll_interval);
        assert_eq!(legacy_config.confirmations_for_eth_event, eth_config.confirmations_for_eth_event);
        assert_eq!(legacy_config.event_expiration_blocks, eth_config.event_expiration_blocks);
    }

    /// 测试错误处理和边界情况
    #[test]
    fn test_error_handling_and_edge_cases() {
        let base_config = NetworkAwareEthWatchConfig::default();

        // 测试极端的链 ID 值
        let edge_cases = vec![
            L1ChainId(0),
            L1ChainId(u64::MAX),
            L1ChainId(u64::MAX - 1),
        ];

        for chain_id in edge_cases {
            // 应该不会 panic，并且应该回退到以太坊配置
            let config = NetworkAwareEthWatchConfigResolver::resolve_config(
                chain_id,
                &base_config,
            );
            
            assert_eq!(config.network_type, NetworkType::Ethereum);
            assert!(config.verify_ethereum_compatibility().is_ok());
        }
    }

    /// 性能测试 - 确保网络检测不会显著影响性能
    #[test]
    fn test_network_detection_performance() {
        use std::time::Instant;
        
        let base_config = NetworkAwareEthWatchConfig::default();
        let test_chains = vec![
            L1ChainId(1), L1ChainId(56), L1ChainId(97), L1ChainId(999)
        ];
        
        let start = Instant::now();
        
        // 执行大量的网络检测操作
        for _ in 0..1000 {
            for &chain_id in &test_chains {
                let _config = NetworkAwareEthWatchConfigResolver::resolve_config(
                    chain_id,
                    &base_config,
                );
            }
        }
        
        let duration = start.elapsed();
        
        // 网络检测应该非常快（少于 100ms 完成 4000 次操作）
        assert!(
            duration.as_millis() < 100,
            "Network detection should be fast, took {}ms",
            duration.as_millis()
        );
    }
}