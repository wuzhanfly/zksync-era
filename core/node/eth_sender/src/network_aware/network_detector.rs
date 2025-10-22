//! 网络类型检测器

use zksync_types::L1ChainId;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkType {
    /// 以太坊网络 (支持 EIP-1559)
    Ethereum,
    /// BSC 网络 (Legacy 交易)
    Bsc,
    /// 其他网络 (默认使用 Legacy)
    Other,
}

/// 根据链 ID 检测网络类型
pub fn detect_network_type(chain_id: L1ChainId) -> NetworkType {
    match chain_id.0 {
        // 以太坊主网和测试网
        1 | 5 | 11155111 => NetworkType::Ethereum,
        // BSC 主网和测试网
        56 | 97 => NetworkType::Bsc,
        // 其他网络默认使用 Legacy
        _ => NetworkType::Other,
    }
}

impl NetworkType {
    /// 是否支持 EIP-1559
    pub fn supports_eip1559(self) -> bool {
        matches!(self, NetworkType::Ethereum)
    }

    /// 是否需要 Legacy 交易模式
    pub fn requires_legacy_mode(self) -> bool {
        matches!(self, NetworkType::Bsc | NetworkType::Other)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_network_detection() {
        // 以太坊网络
        assert_eq!(detect_network_type(L1ChainId(1)), NetworkType::Ethereum);
        assert_eq!(detect_network_type(L1ChainId(5)), NetworkType::Ethereum);
        assert_eq!(detect_network_type(L1ChainId(11155111)), NetworkType::Ethereum);

        // BSC 网络
        assert_eq!(detect_network_type(L1ChainId(56)), NetworkType::Bsc);
        assert_eq!(detect_network_type(L1ChainId(97)), NetworkType::Bsc);

        // 其他网络
        assert_eq!(detect_network_type(L1ChainId(137)), NetworkType::Other);
    }

    #[test]
    fn test_eip1559_support() {
        assert!(NetworkType::Ethereum.supports_eip1559());
        assert!(!NetworkType::Bsc.supports_eip1559());
        assert!(!NetworkType::Other.supports_eip1559());
    }
}
