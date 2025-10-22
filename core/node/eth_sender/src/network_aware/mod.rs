//! 网络感知的 ETH Sender 组件
//! 
//! 这个模块提供了网络感知的功能，允许 ZKsync Era 在不同的区块链网络上运行：
//! - 以太坊：完全的 EIP-1559 支持
//! - BSC：Legacy 交易模式支持  
//! - 其他网络：自适应兼容性

pub mod network_detector;

pub use network_detector::{NetworkType, detect_network_type};
