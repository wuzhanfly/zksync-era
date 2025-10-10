use anyhow::Result;
use ethers::providers::Middleware;
use serde::{Deserialize, Serialize};
use zkstack_cli_common::ethereum::get_ethers_provider;
use zkstack_cli_types::L1Network;

/// BSC 费用计算器 - 用于优化 zkSync Era 在 BSC 上的费用模型
pub struct BscFeeCalculator {
    l1_network: L1Network,
    rpc_url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscFeeAnalysis {
    pub network: String,
    pub current_gas_price_gwei: f64,
    pub recommended_l2_gas_price_wei: u64,
    pub batch_overhead_l1_gas: u64,
    pub pubdata_price_scale_factor: f64,
    pub estimated_tx_cost_usd: f64,
    pub cost_comparison_vs_ethereum: CostComparison,
    pub optimization_recommendations: Vec<OptimizationRecommendation>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CostComparison {
    pub bsc_cost_usd: f64,
    pub ethereum_cost_usd: f64,
    pub savings_percentage: f64,
    pub savings_usd: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationRecommendation {
    pub parameter: String,
    pub current_value: String,
    pub recommended_value: String,
    pub impact: String,
    pub reasoning: String,
}

impl BscFeeCalculator {
    pub fn new(l1_network: L1Network, rpc_url: String) -> Self {
        Self { l1_network, rpc_url }
    }

    /// 分析 BSC 网络并生成费用优化建议
    pub async fn analyze_and_optimize(&self) -> Result<BscFeeAnalysis> {
        println!("🔍 分析 BSC 网络费用结构...");

        let provider = get_ethers_provider(&self.rpc_url)?;
        
        // 获取当前网络状态
        let gas_price = provider.get_gas_price().await?;
        let latest_block = provider.get_block_number().await?;
        let _block = provider.get_block(latest_block).await?;

        let gas_price_gwei = gas_price.as_u64() as f64 / 1e9;
        
        println!("📊 当前网络状态:");
        println!("   Gas 价格: {:.2} Gwei", gas_price_gwei);
        println!("   最新区块: {}", latest_block);

        // 计算优化参数
        let analysis = self.calculate_optimized_parameters(gas_price_gwei).await?;
        
        println!("✅ 费用分析完成");
        Ok(analysis)
    }

    async fn calculate_optimized_parameters(&self, current_gas_price_gwei: f64) -> Result<BscFeeAnalysis> {
        let network_name = match self.l1_network {
            L1Network::BscMainnet => "BSC Mainnet",
            L1Network::BscTestnet => "BSC Testnet",
            _ => "Unknown BSC Network",
        };

        // 1. 计算推荐的 L2 gas 价格
        let recommended_l2_gas_price = self.calculate_l2_gas_price(current_gas_price_gwei);

        // 2. 计算批次开销
        let batch_overhead = self.calculate_batch_overhead(current_gas_price_gwei);

        // 3. 计算 pubdata 价格缩放因子
        let pubdata_scale_factor = self.calculate_pubdata_scale_factor();

        // 4. 估算交易成本
        let estimated_tx_cost = self.estimate_transaction_cost(
            recommended_l2_gas_price,
            batch_overhead,
            current_gas_price_gwei,
        );

        // 5. 与以太坊成本比较
        let cost_comparison = self.compare_with_ethereum_costs(estimated_tx_cost);

        // 6. 生成优化建议
        let recommendations = self.generate_optimization_recommendations(
            current_gas_price_gwei,
            recommended_l2_gas_price,
            batch_overhead,
            pubdata_scale_factor,
        );

        Ok(BscFeeAnalysis {
            network: network_name.to_string(),
            current_gas_price_gwei,
            recommended_l2_gas_price_wei: recommended_l2_gas_price,
            batch_overhead_l1_gas: batch_overhead,
            pubdata_price_scale_factor: pubdata_scale_factor,
            estimated_tx_cost_usd: estimated_tx_cost,
            cost_comparison_vs_ethereum: cost_comparison,
            optimization_recommendations: recommendations,
        })
    }

    fn calculate_l2_gas_price(&self, l1_gas_price_gwei: f64) -> u64 {
        // BSC 的 L2 gas 价格应该反映其低成本优势
        let base_l2_price = match self.l1_network {
            L1Network::BscMainnet => {
                // 主网：考虑运营成本和合理利润
                let bnb_price_usd = 1000.0; // 假设 BNB 价格
                let target_cost_usd = 0.01; // 目标：1 美分每笔交易
                let gas_per_tx = 21000.0; // 标准转账 gas
                
                (target_cost_usd / bnb_price_usd * 1e18 / gas_per_tx) as u64
            }
            L1Network::BscTestnet => {
                // 测试网：极低价格以鼓励测试
                1_000_000 // 0.001 Gwei
            }
            _ => 5_000_000, // 默认值
        };

        // 根据当前 L1 gas 价格动态调整
        let adjustment_factor = if l1_gas_price_gwei > 10.0 {
            1.2 // L1 拥堵时稍微提高 L2 价格
        } else if l1_gas_price_gwei < 3.0 {
            0.8 // L1 便宜时降低 L2 价格
        } else {
            1.0
        };

        (base_l2_price as f64 * adjustment_factor) as u64
    }

    fn calculate_batch_overhead(&self, l1_gas_price_gwei: f64) -> u64 {
        // BSC 的批次开销应该大幅低于以太坊
        let ethereum_batch_overhead = 800_000u64; // 以太坊典型值
        
        let bsc_reduction_factor = match self.l1_network {
            L1Network::BscMainnet => {
                // 主网：根据实际 gas 成本差异计算
                let eth_gas_price_gwei = 30.0; // 假设以太坊 gas 价格
                let cost_ratio = l1_gas_price_gwei / eth_gas_price_gwei;
                cost_ratio.min(0.2) // 最多降低到以太坊的 20%
            }
            L1Network::BscTestnet => {
                0.1 // 测试网降低到 10%
            }
            _ => 0.15,
        };

        (ethereum_batch_overhead as f64 * bsc_reduction_factor) as u64
    }

    fn calculate_pubdata_scale_factor(&self) -> f64 {
        // BSC 的 calldata 成本比以太坊低
        match self.l1_network {
            L1Network::BscMainnet => 0.15, // 主网：15% 的以太坊成本
            L1Network::BscTestnet => 0.05, // 测试网：5% 的以太坊成本
            _ => 0.1,
        }
    }

    fn estimate_transaction_cost(
        &self,
        l2_gas_price_wei: u64,
        batch_overhead_gas: u64,
        l1_gas_price_gwei: f64,
    ) -> f64 {
        // 估算一笔标准转账的成本
        let l2_gas_used = 21_000u64; // 标准转账
        let transactions_per_batch = 100.0; // 假设每批次 100 笔交易

        // L2 计算成本
        let l2_cost_wei = l2_gas_used * l2_gas_price_wei;

        // L1 批次成本分摊
        let l1_cost_per_tx_wei = (batch_overhead_gas as f64 / transactions_per_batch) 
            * l1_gas_price_gwei * 1e9;

        // 总成本 (wei)
        let total_cost_wei = l2_cost_wei as f64 + l1_cost_per_tx_wei;

        // 转换为 USD (假设 BNB 价格)
        let bnb_price_usd = match self.l1_network {
            L1Network::BscMainnet => 300.0,
            L1Network::BscTestnet => 300.0, // 使用相同价格进行比较
            _ => 300.0,
        };

        total_cost_wei / 1e18 * bnb_price_usd
    }

    fn compare_with_ethereum_costs(&self, bsc_cost_usd: f64) -> CostComparison {
        // 以太坊典型交易成本 (假设)
        let ethereum_cost_usd = match self.l1_network {
            L1Network::BscMainnet => 5.0, // 主网对比
            L1Network::BscTestnet => 1.0, // 测试网对比 (Sepolia)
            _ => 3.0,
        };

        let savings_usd = ethereum_cost_usd - bsc_cost_usd;
        let savings_percentage = (savings_usd / ethereum_cost_usd) * 100.0;

        CostComparison {
            bsc_cost_usd,
            ethereum_cost_usd,
            savings_percentage,
            savings_usd,
        }
    }

    fn generate_optimization_recommendations(
        &self,
        current_gas_price_gwei: f64,
        recommended_l2_gas_price: u64,
        batch_overhead: u64,
        pubdata_scale_factor: f64,
    ) -> Vec<OptimizationRecommendation> {
        let mut recommendations = Vec::new();

        // L2 Gas 价格建议
        recommendations.push(OptimizationRecommendation {
            parameter: "minimal_l2_gas_price".to_string(),
            current_value: "100000000".to_string(), // 以太坊默认值
            recommended_value: recommended_l2_gas_price.to_string(),
            impact: "High".to_string(),
            reasoning: format!(
                "BSC 的低成本允许将 L2 gas 价格降低到 {} wei，大幅降低用户交易成本",
                recommended_l2_gas_price
            ),
        });

        // 批次开销建议
        recommendations.push(OptimizationRecommendation {
            parameter: "batch_overhead_l1_gas".to_string(),
            current_value: "800000".to_string(), // 以太坊默认值
            recommended_value: batch_overhead.to_string(),
            impact: "Critical".to_string(),
            reasoning: format!(
                "BSC 的 gas 成本比以太坊低 {}%，批次开销可以从 800K 降低到 {}",
                ((800000 - batch_overhead) as f64 / 800000.0 * 100.0) as u32,
                batch_overhead
            ),
        });

        // Pubdata 价格建议
        recommendations.push(OptimizationRecommendation {
            parameter: "l1_pubdata_price_scale_factor".to_string(),
            current_value: "1.0".to_string(),
            recommended_value: pubdata_scale_factor.to_string(),
            impact: "Medium".to_string(),
            reasoning: format!(
                "BSC 的 calldata 成本更低，pubdata 价格可以缩放到以太坊的 {}%",
                (pubdata_scale_factor * 100.0) as u32
            ),
        });

        // 网络特定建议
        if current_gas_price_gwei < 3.0 {
            recommendations.push(OptimizationRecommendation {
                parameter: "aggressive_batching_enabled".to_string(),
                current_value: "false".to_string(),
                recommended_value: "true".to_string(),
                impact: "Medium".to_string(),
                reasoning: "当前 BSC gas 价格很低，可以启用更激进的批处理策略".to_string(),
            });
        }

        if matches!(self.l1_network, L1Network::BscTestnet) {
            recommendations.push(OptimizationRecommendation {
                parameter: "fast_finality_enabled".to_string(),
                current_value: "false".to_string(),
                recommended_value: "true".to_string(),
                impact: "Low".to_string(),
                reasoning: "测试网可以启用快速最终性以加速开发和测试".to_string(),
            });
        }

        recommendations
    }

    /// 生成配置文件更新建议
    pub fn generate_config_updates(&self, analysis: &BscFeeAnalysis) -> String {
        let mut config = String::new();
        
        config.push_str("# BSC 优化配置建议\n");
        config.push_str("# 基于实时网络分析生成\n\n");

        config.push_str(&format!(
            "# 当前 BSC {} gas 价格: {:.2} Gwei\n",
            analysis.network, analysis.current_gas_price_gwei
        ));

        config.push_str(&format!(
            "CHAIN_STATE_KEEPER_MINIMAL_L2_GAS_PRICE = \"{}\"\n",
            analysis.recommended_l2_gas_price_wei
        ));

        config.push_str(&format!(
            "CHAIN_STATE_KEEPER_BATCH_OVERHEAD_L1_GAS = \"{}\"\n",
            analysis.batch_overhead_l1_gas
        ));

        config.push_str(&format!(
            "BSC_PUBDATA_PRICE_SCALE_FACTOR = \"{}\"\n",
            analysis.pubdata_price_scale_factor
        ));

        config.push_str(&format!(
            "\n# 预估交易成本: ${:.4} USD\n",
            analysis.estimated_tx_cost_usd
        ));

        config.push_str(&format!(
            "# 相比以太坊节省: {:.1}% (${:.2} USD)\n",
            analysis.cost_comparison_vs_ethereum.savings_percentage,
            analysis.cost_comparison_vs_ethereum.savings_usd
        ));

        config
    }
}

/// 命令行接口
pub async fn analyze_bsc_fees(
    l1_network: L1Network,
    rpc_url: String,
    output_format: Option<String>,
) -> Result<()> {
    if !l1_network.is_bsc_network() {
        anyhow::bail!("只支持 BSC 网络的费用分析");
    }

    let calculator = BscFeeCalculator::new(l1_network, rpc_url);
    let analysis = calculator.analyze_and_optimize().await?;

    match output_format.as_deref() {
        Some("json") => {
            println!("{}", serde_json::to_string_pretty(&analysis)?);
        }
        Some("config") => {
            println!("{}", calculator.generate_config_updates(&analysis));
        }
        _ => {
            print_analysis_report(&analysis);
        }
    }

    Ok(())
}

fn print_analysis_report(analysis: &BscFeeAnalysis) {
    println!("\n🎯 BSC 费用优化分析报告");
    println!("═══════════════════════════════════════");
    
    println!("\n📊 网络状态");
    println!("   网络: {}", analysis.network);
    println!("   当前 Gas 价格: {:.2} Gwei", analysis.current_gas_price_gwei);
    
    println!("\n💰 费用优化建议");
    println!("   推荐 L2 Gas 价格: {} wei ({:.3} Gwei)", 
             analysis.recommended_l2_gas_price_wei,
             analysis.recommended_l2_gas_price_wei as f64 / 1e9);
    println!("   批次开销: {} gas", analysis.batch_overhead_l1_gas);
    println!("   Pubdata 价格缩放: {:.1}%", analysis.pubdata_price_scale_factor * 100.0);
    
    println!("\n💵 成本分析");
    println!("   预估交易成本: ${:.4} USD", analysis.estimated_tx_cost_usd);
    println!("   以太坊交易成本: ${:.2} USD", analysis.cost_comparison_vs_ethereum.ethereum_cost_usd);
    println!("   节省金额: ${:.2} USD ({:.1}%)", 
             analysis.cost_comparison_vs_ethereum.savings_usd,
             analysis.cost_comparison_vs_ethereum.savings_percentage);
    
    println!("\n🔧 优化建议");
    for (i, rec) in analysis.optimization_recommendations.iter().enumerate() {
        println!("   {}. {} (影响: {})", i + 1, rec.parameter, rec.impact);
        println!("      当前值: {}", rec.current_value);
        println!("      建议值: {}", rec.recommended_value);
        println!("      原因: {}", rec.reasoning);
        println!();
    }
}