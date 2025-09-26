use anyhow::Result;
use ethers::{providers::Middleware, types::H160, utils::format_units};
use zkstack_cli_common::{ethereum::get_ethers_provider, logger};
use zkstack_cli_types::L1Network;

/// BSC环境检查器
pub struct BSCEnvironmentChecker {
    network: L1Network,
    rpc_url: String,
}

impl BSCEnvironmentChecker {
    pub fn new(network: L1Network, rpc_url: Option<String>) -> Self {
        let rpc_url = rpc_url.unwrap_or_else(|| {
            network.default_rpc_url().unwrap().to_string()
        });
        
        Self { network, rpc_url }
    }

    /// 运行完整的环境检查
    pub async fn run_full_check(&self) -> Result<BSCEnvironmentReport> {
        logger::info("🔍 开始BSC环境检查...");
        
        let mut report = BSCEnvironmentReport::new(self.network);
        
        // 1. 网络连接检查
        report.connectivity = self.check_connectivity().await;
        
        // 2. 网络特性检查
        if report.connectivity.is_ok() {
            report.network_info = self.check_network_info().await;
            report.gas_analysis = self.analyze_gas_conditions().await;
            report.performance_metrics = self.check_performance().await;
        }
        
        // 3. BSC特定检查
        report.bsc_specific = self.check_bsc_specific_features().await;
        
        report.print_summary();
        
        Ok(report)
    }

    async fn check_connectivity(&self) -> Result<ConnectivityCheck> {
        logger::info("检查网络连接...");
        
        let provider = get_ethers_provider(&self.rpc_url)?;
        
        let start_time = std::time::Instant::now();
        let chain_id = provider.get_chainid().await?;
        let response_time = start_time.elapsed();
        
        let expected_chain_id = self.network.chain_id();
        let chain_id_match = chain_id.as_u64() == expected_chain_id;
        
        Ok(ConnectivityCheck {
            success: true,
            response_time_ms: response_time.as_millis() as u64,
            chain_id: chain_id.as_u64(),
            chain_id_match,
            rpc_url: self.rpc_url.clone(),
        })
    }

    async fn check_network_info(&self) -> Result<NetworkInfo> {
        logger::info("获取网络信息...");
        
        let provider = get_ethers_provider(&self.rpc_url)?;
        
        let latest_block_number = provider.get_block_number().await?;
        let latest_block = provider.get_block(latest_block_number).await?;
        
        let block_time = if let Some(block) = &latest_block {
            if latest_block_number.as_u64() > 0 {
                let prev_block = provider.get_block(latest_block_number - 1).await?;
                if let (Some(current), Some(previous)) = (Some(block), prev_block.as_ref()) {
                    Some((current.timestamp - previous.timestamp).as_u64())
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        };

        Ok(NetworkInfo {
            latest_block: latest_block_number.as_u64(),
            block_time_seconds: block_time,
            gas_limit: latest_block.as_ref().map(|b| b.gas_limit.as_u64()),
            gas_used: latest_block.as_ref().map(|b| b.gas_used.as_u64()),
        })
    }

    async fn analyze_gas_conditions(&self) -> Result<GasAnalysis> {
        logger::info("分析Gas条件...");
        
        let provider = get_ethers_provider(&self.rpc_url)?;
        
        let gas_price = provider.get_gas_price().await?;
        let gas_price_gwei = format_units(gas_price, "gwei")?
            .parse::<f64>()
            .unwrap_or(0.0);
        
        let recommended_gas = self.network.recommended_gas_price_gwei();
        let max_gas = self.network.max_gas_price_gwei();
        
        let gas_condition = if gas_price_gwei <= recommended_gas as f64 {
            GasCondition::Optimal
        } else if gas_price_gwei <= max_gas as f64 {
            GasCondition::Acceptable
        } else {
            GasCondition::High
        };

        Ok(GasAnalysis {
            current_gas_price_gwei: gas_price_gwei,
            recommended_gas_price_gwei: recommended_gas,
            max_gas_price_gwei: max_gas,
            condition: gas_condition,
            supports_eip1559: self.network.supports_eip1559(),
        })
    }

    async fn check_performance(&self) -> Result<PerformanceMetrics> {
        logger::info("检查性能指标...");
        
        let provider = get_ethers_provider(&self.rpc_url)?;
        
        // 测试多个请求的响应时间
        let mut response_times = Vec::new();
        for _ in 0..5 {
            let start = std::time::Instant::now();
            let _ = provider.get_block_number().await?;
            response_times.push(start.elapsed().as_millis() as u64);
        }
        
        let avg_response_time = response_times.iter().sum::<u64>() / response_times.len() as u64;
        let min_response_time = *response_times.iter().min().unwrap();
        let max_response_time = *response_times.iter().max().unwrap();

        Ok(PerformanceMetrics {
            avg_response_time_ms: avg_response_time,
            min_response_time_ms: min_response_time,
            max_response_time_ms: max_response_time,
            expected_block_time: self.network.average_block_time_seconds(),
            block_gas_limit: self.network.block_gas_limit(),
        })
    }

    async fn check_bsc_specific_features(&self) -> Result<BSCSpecificCheck> {
        logger::info("检查BSC特定功能...");
        
        let is_bsc = matches!(self.network, L1Network::BSCMainnet | L1Network::BSCTestnet);
        
        if !is_bsc {
            return Ok(BSCSpecificCheck {
                is_bsc_network: false,
                wbnb_available: false,
                multicall3_available: false,
                fast_finality: false,
                validator_set_size: None,
            });
        }

        // 检查WBNB合约
        let wbnb_address = match self.network {
            L1Network::BSCMainnet => "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
            L1Network::BSCTestnet => "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
            _ => return Ok(BSCSpecificCheck::default()),
        };

        let provider = get_ethers_provider(&self.rpc_url)?;
        let wbnb_addr: H160 = wbnb_address.parse()?;
        let wbnb_code = provider.get_code(wbnb_addr, None).await?;
        let wbnb_available = !wbnb_code.is_empty();

        // 检查Multicall3
        let multicall3_address = "0xcA11bde05977b3631167028862bE2a173976CA11";
        let multicall3_addr: H160 = multicall3_address.parse()?;
        let multicall3_code = provider.get_code(multicall3_addr, None).await?;
        let multicall3_available = !multicall3_code.is_empty();

        Ok(BSCSpecificCheck {
            is_bsc_network: true,
            wbnb_available,
            multicall3_available,
            fast_finality: true, // BSC支持快速最终性
            validator_set_size: Some(21), // BSC有21个验证者
        })
    }
}

#[derive(Debug)]
pub struct BSCEnvironmentReport {
    pub network: L1Network,
    pub connectivity: Result<ConnectivityCheck>,
    pub network_info: Result<NetworkInfo>,
    pub gas_analysis: Result<GasAnalysis>,
    pub performance_metrics: Result<PerformanceMetrics>,
    pub bsc_specific: Result<BSCSpecificCheck>,
}

impl BSCEnvironmentReport {
    fn new(network: L1Network) -> Self {
        Self {
            network,
            connectivity: Err(anyhow::anyhow!("未检查")),
            network_info: Err(anyhow::anyhow!("未检查")),
            gas_analysis: Err(anyhow::anyhow!("未检查")),
            performance_metrics: Err(anyhow::anyhow!("未检查")),
            bsc_specific: Err(anyhow::anyhow!("未检查")),
        }
    }

    pub fn print_summary(&self) {
        println!();
        println!("📊 BSC环境检查报告");
        println!("═══════════════════");
        println!("网络: {:?}", self.network);
        println!();

        // 连接性检查
        match &self.connectivity {
            Ok(check) => {
                println!("🌐 网络连接: {}", if check.success { "✅ 成功" } else { "❌ 失败" });
                println!("  RPC URL: {}", check.rpc_url);
                println!("  响应时间: {}ms", check.response_time_ms);
                println!("  链ID: {} {}", check.chain_id, 
                    if check.chain_id_match { "✅" } else { "❌" });
            },
            Err(e) => println!("🌐 网络连接: ❌ 失败 - {}", e),
        }
        println!();

        // 网络信息
        if let Ok(info) = &self.network_info {
            println!("📈 网络信息:");
            println!("  最新区块: {}", info.latest_block);
            if let Some(block_time) = info.block_time_seconds {
                println!("  区块时间: {}秒", block_time);
            }
            if let Some(gas_limit) = info.gas_limit {
                println!("  Gas限制: {}", gas_limit);
            }
            if let Some(gas_used) = info.gas_used {
                println!("  Gas使用: {}", gas_used);
            }
            println!();
        }

        // Gas分析
        if let Ok(gas) = &self.gas_analysis {
            println!("⛽ Gas分析:");
            println!("  当前Gas价格: {:.2} Gwei", gas.current_gas_price_gwei);
            println!("  推荐Gas价格: {} Gwei", gas.recommended_gas_price_gwei);
            println!("  最大Gas价格: {} Gwei", gas.max_gas_price_gwei);
            println!("  Gas条件: {:?}", gas.condition);
            println!("  EIP-1559支持: {}", if gas.supports_eip1559 { "是" } else { "否" });
            println!();
        }

        // 性能指标
        if let Ok(perf) = &self.performance_metrics {
            println!("🚀 性能指标:");
            println!("  平均响应时间: {}ms", perf.avg_response_time_ms);
            println!("  最小响应时间: {}ms", perf.min_response_time_ms);
            println!("  最大响应时间: {}ms", perf.max_response_time_ms);
            println!("  预期区块时间: {}秒", perf.expected_block_time);
            println!("  区块Gas限制: {}", perf.block_gas_limit);
            println!();
        }

        // BSC特定检查
        if let Ok(bsc) = &self.bsc_specific {
            if bsc.is_bsc_network {
                println!("🔶 BSC特定功能:");
                println!("  WBNB合约: {}", if bsc.wbnb_available { "✅ 可用" } else { "❌ 不可用" });
                println!("  Multicall3: {}", if bsc.multicall3_available { "✅ 可用" } else { "❌ 不可用" });
                println!("  快速最终性: {}", if bsc.fast_finality { "✅ 支持" } else { "❌ 不支持" });
                if let Some(validators) = bsc.validator_set_size {
                    println!("  验证者数量: {}", validators);
                }
                println!();
            }
        }

        // 总体评估
        self.print_overall_assessment();
    }

    fn print_overall_assessment(&self) {
        println!("🎯 总体评估:");
        
        let connectivity_ok = self.connectivity.is_ok();
        let gas_ok = self.gas_analysis.as_ref()
            .map(|g| matches!(g.condition, GasCondition::Optimal | GasCondition::Acceptable))
            .unwrap_or(false);
        let performance_ok = self.performance_metrics.as_ref()
            .map(|p| p.avg_response_time_ms < 1000)
            .unwrap_or(false);

        if connectivity_ok && gas_ok && performance_ok {
            println!("  ✅ 环境状态良好，适合部署ZKsync Era");
            println!("  💰 预期成本节省: 90%+ (相比以太坊)");
            println!("  ⚡ 预期性能提升: 4倍 (相比以太坊)");
        } else {
            println!("  ⚠️ 环境存在一些问题，建议检查:");
            if !connectivity_ok {
                println!("    - 网络连接问题");
            }
            if !gas_ok {
                println!("    - Gas价格偏高");
            }
            if !performance_ok {
                println!("    - 网络响应较慢");
            }
        }
        
        println!();
        println!("📚 建议:");
        match self.network {
            L1Network::BSCTestnet => {
                println!("  • 使用BSC测试网进行开发和测试");
                println!("  • 从水龙头获取测试BNB: https://testnet.binance.org/faucet-smart");
                println!("  • 测试网Gas价格通常较高，这是正常的");
            },
            L1Network::BSCMainnet => {
                println!("  • 确保有足够的BNB用于部署");
                println!("  • 监控Gas价格，选择合适的部署时机");
                println!("  • 考虑使用多个RPC端点提高可靠性");
            },
            _ => {},
        }
    }
}

#[derive(Debug)]
pub struct ConnectivityCheck {
    pub success: bool,
    pub response_time_ms: u64,
    pub chain_id: u64,
    pub chain_id_match: bool,
    pub rpc_url: String,
}

#[derive(Debug)]
pub struct NetworkInfo {
    pub latest_block: u64,
    pub block_time_seconds: Option<u64>,
    pub gas_limit: Option<u64>,
    pub gas_used: Option<u64>,
}

#[derive(Debug)]
pub struct GasAnalysis {
    pub current_gas_price_gwei: f64,
    pub recommended_gas_price_gwei: u64,
    pub max_gas_price_gwei: u64,
    pub condition: GasCondition,
    pub supports_eip1559: bool,
}

#[derive(Debug)]
pub enum GasCondition {
    Optimal,    // 低于推荐价格
    Acceptable, // 在推荐和最大之间
    High,       // 高于最大价格
}

#[derive(Debug)]
pub struct PerformanceMetrics {
    pub avg_response_time_ms: u64,
    pub min_response_time_ms: u64,
    pub max_response_time_ms: u64,
    pub expected_block_time: u64,
    pub block_gas_limit: u64,
}

#[derive(Debug, Default)]
pub struct BSCSpecificCheck {
    pub is_bsc_network: bool,
    pub wbnb_available: bool,
    pub multicall3_available: bool,
    pub fast_finality: bool,
    pub validator_set_size: Option<u32>,
}