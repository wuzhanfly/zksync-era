use anyhow::Result;
use ethers::{providers::Middleware, types::U256};
use serde::{Deserialize, Serialize};
use std::time::{Duration, Instant};
use tokio::time::sleep;
use zkstack_cli_common::ethereum::get_ethers_provider;
use zkstack_cli_types::L1Network;

/// BSC 网络性能监控器
pub struct BscNetworkMonitor {
    l1_network: L1Network,
    rpc_url: String,
    monitoring_interval: Duration,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BscNetworkMetrics {
    pub timestamp: u64,
    pub network: String,
    pub block_number: u64,
    pub block_time_seconds: f64,
    pub gas_price_gwei: f64,
    pub network_utilization: f64,
    pub tps_estimate: f64,
    pub performance_score: f64,
    pub recommendations: Vec<PerformanceRecommendation>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceRecommendation {
    pub category: String,
    pub message: String,
    pub priority: String, // High, Medium, Low
    pub action: String,
}

#[derive(Debug, Clone)]
pub struct BlockTimeAnalysis {
    pub average_block_time: f64,
    pub _block_time_variance: f64,
    pub is_stable: bool,
}

impl BscNetworkMonitor {
    pub fn new(l1_network: L1Network, rpc_url: String) -> Self {
        Self {
            l1_network,
            rpc_url,
            monitoring_interval: Duration::from_secs(30), // 30 秒监控间隔
        }
    }

    /// 开始监控 BSC 网络性能
    pub async fn start_monitoring(&self, duration_minutes: u64) -> Result<Vec<BscNetworkMetrics>> {
        println!("🔍 开始监控 BSC 网络性能...");
        println!("   网络: {:?}", self.l1_network);
        println!("   监控时长: {} 分钟", duration_minutes);
        println!("   监控间隔: {} 秒", self.monitoring_interval.as_secs());

        let mut metrics_history = Vec::new();
        let end_time = Instant::now() + Duration::from_secs(duration_minutes * 60);

        while Instant::now() < end_time {
            match self.collect_metrics().await {
                Ok(metrics) => {
                    self.print_real_time_metrics(&metrics);
                    metrics_history.push(metrics);
                }
                Err(e) => {
                    eprintln!("❌ 收集指标时出错: {}", e);
                }
            }

            sleep(self.monitoring_interval).await;
        }

        println!("\n✅ 监控完成，共收集 {} 个数据点", metrics_history.len());
        Ok(metrics_history)
    }

    /// 收集当前网络指标
    pub async fn collect_metrics(&self) -> Result<BscNetworkMetrics> {
        let provider = get_ethers_provider(&self.rpc_url)?;
        let _start_time = Instant::now();

        // 获取基础网络信息
        let block_number = provider.get_block_number().await?;
        let gas_price = provider.get_gas_price().await?;
        let latest_block = provider
            .get_block(block_number)
            .await?
            .ok_or_else(|| anyhow::anyhow!("无法获取最新区块"))?;

        // 分析区块时间
        let block_time_analysis = self
            .analyze_block_times(&provider, U256::from(block_number.as_u64()))
            .await?;

        // 计算网络利用率
        let network_utilization = self.calculate_network_utilization(&latest_block);

        // 估算 TPS
        let tps_estimate = self
            .estimate_tps(&provider, U256::from(block_number.as_u64()))
            .await?;

        // 计算性能评分
        let performance_score = self.calculate_performance_score(
            block_time_analysis.average_block_time,
            gas_price.as_u64() as f64 / 1e9,
            network_utilization,
            tps_estimate,
        );

        // 生成建议
        let recommendations = self.generate_performance_recommendations(
            &block_time_analysis,
            gas_price.as_u64() as f64 / 1e9,
            network_utilization,
            tps_estimate,
        );

        let metrics = BscNetworkMetrics {
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)?
                .as_secs(),
            network: format!("{:?}", self.l1_network),
            block_number: block_number.as_u64(),
            block_time_seconds: block_time_analysis.average_block_time,
            gas_price_gwei: gas_price.as_u64() as f64 / 1e9,
            network_utilization,
            tps_estimate,
            performance_score,
            recommendations,
        };

        Ok(metrics)
    }

    async fn analyze_block_times<M: Middleware + 'static>(
        &self,
        provider: &M,
        current_block: U256,
    ) -> Result<BlockTimeAnalysis> {
        let sample_size = 10u64; // 分析最近 10 个区块
        let mut block_times = Vec::new();

        for i in 0..sample_size {
            if current_block.as_u64() < i + 1 {
                break;
            }

            let block_num = current_block - i;
            let prev_block_num = block_num - 1;

            if let (Some(block), Some(prev_block)) = (
                provider.get_block(block_num.as_u64()).await?,
                provider.get_block(prev_block_num.as_u64()).await?,
            ) {
                let block_time =
                    block.timestamp.as_u64() as f64 - prev_block.timestamp.as_u64() as f64;
                block_times.push(block_time);
            }
        }

        if block_times.is_empty() {
            return Ok(BlockTimeAnalysis {
                average_block_time: 3.0, // BSC 默认出块时间
                _block_time_variance: 0.0,
                is_stable: true,
            });
        }

        let average = block_times.iter().sum::<f64>() / block_times.len() as f64;
        let variance = block_times
            .iter()
            .map(|&time| (time - average).powi(2))
            .sum::<f64>()
            / block_times.len() as f64;

        let is_stable = variance < 1.0; // 如果方差小于 1 秒，认为是稳定的

        Ok(BlockTimeAnalysis {
            average_block_time: average,
            _block_time_variance: variance,
            is_stable,
        })
    }

    fn calculate_network_utilization(
        &self,
        block: &ethers::types::Block<ethers::types::H256>,
    ) -> f64 {
        let gas_used = block.gas_used;
        let gas_limit = block.gas_limit;
        gas_used.as_u64() as f64 / gas_limit.as_u64() as f64
    }

    async fn estimate_tps<M: Middleware + 'static>(
        &self,
        provider: &M,
        current_block: U256,
    ) -> Result<f64> {
        let sample_blocks = 5u64;
        let mut total_transactions = 0u64;
        let mut total_time = 0f64;

        for i in 0..sample_blocks {
            if current_block.as_u64() < i + 1 {
                break;
            }

            let block_num = current_block - i;
            if let Some(block) = provider.get_block_with_txs(block_num.as_u64()).await? {
                total_transactions += block.transactions.len() as u64;

                if i > 0 {
                    if let Some(prev_block) = provider.get_block((block_num - 1).as_u64()).await? {
                        total_time +=
                            block.timestamp.as_u64() as f64 - prev_block.timestamp.as_u64() as f64;
                    }
                }
            }
        }

        if total_time > 0.0 {
            Ok(total_transactions as f64 / total_time)
        } else {
            Ok(0.0)
        }
    }

    fn calculate_performance_score(
        &self,
        block_time: f64,
        gas_price_gwei: f64,
        utilization: f64,
        tps: f64,
    ) -> f64 {
        let _score = 100.0;

        // 区块时间评分 (BSC 目标是 3 秒)
        let block_time_score = if block_time <= 3.5 {
            100.0
        } else if block_time <= 5.0 {
            80.0
        } else {
            50.0
        };

        // Gas 价格评分 (BSC 目标是低 gas 价格)
        let gas_price_score = if gas_price_gwei <= 5.0 {
            100.0
        } else if gas_price_gwei <= 10.0 {
            80.0
        } else if gas_price_gwei <= 20.0 {
            60.0
        } else {
            30.0
        };

        // 网络利用率评分 (适中的利用率最好)
        let utilization_score = if utilization >= 0.3 && utilization <= 0.7 {
            100.0
        } else if utilization >= 0.1 && utilization <= 0.9 {
            80.0
        } else {
            50.0
        };

        // TPS 评分
        let tps_score = if tps >= 50.0 {
            100.0
        } else if tps >= 20.0 {
            80.0
        } else if tps >= 10.0 {
            60.0
        } else {
            40.0
        };

        // 加权平均
        block_time_score * 0.3 + gas_price_score * 0.3 + utilization_score * 0.2 + tps_score * 0.2
    }

    fn generate_performance_recommendations(
        &self,
        block_time_analysis: &BlockTimeAnalysis,
        gas_price_gwei: f64,
        utilization: f64,
        tps: f64,
    ) -> Vec<PerformanceRecommendation> {
        let mut recommendations = Vec::new();

        // 区块时间建议
        if block_time_analysis.average_block_time > 4.0 {
            recommendations.push(PerformanceRecommendation {
                category: "Block Time".to_string(),
                message: format!(
                    "区块时间 ({:.1}s) 超过 BSC 标准 (3s)，可能影响交易确认速度",
                    block_time_analysis.average_block_time
                ),
                priority: "Medium".to_string(),
                action: "考虑增加 ETH_WATCH_CONFIRMATIONS_FOR_ETH_EVENT 以适应较慢的出块"
                    .to_string(),
            });
        }

        if !block_time_analysis.is_stable {
            recommendations.push(PerformanceRecommendation {
                category: "Block Time Stability".to_string(),
                message: "区块时间不稳定，可能导致交易确认时间不可预测".to_string(),
                priority: "Low".to_string(),
                action: "监控网络状况，考虑使用多个 RPC 端点".to_string(),
            });
        }

        // Gas 价格建议
        if gas_price_gwei > 15.0 {
            recommendations.push(PerformanceRecommendation {
                category: "Gas Price".to_string(),
                message: format!(
                    "Gas 价格 ({:.1} Gwei) 较高，可能影响 BSC 的成本优势",
                    gas_price_gwei
                ),
                priority: "High".to_string(),
                action: "调整 ETH_SENDER_MAX_GAS_PRICE 和费用模型参数".to_string(),
            });
        } else if gas_price_gwei < 3.0 {
            recommendations.push(PerformanceRecommendation {
                category: "Gas Price".to_string(),
                message: format!(
                    "Gas 价格 ({:.1} Gwei) 很低，可以更激进地优化费用",
                    gas_price_gwei
                ),
                priority: "Low".to_string(),
                action: "考虑降低 minimal_l2_gas_price 以传递更多成本优势给用户".to_string(),
            });
        }

        // 网络利用率建议
        if utilization > 0.9 {
            recommendations.push(PerformanceRecommendation {
                category: "Network Utilization".to_string(),
                message: format!(
                    "网络利用率 ({:.1}%) 很高，可能出现拥堵",
                    utilization * 100.0
                ),
                priority: "High".to_string(),
                action: "增加 max_txs_in_flight 和 transaction_slots 以提高吞吐量".to_string(),
            });
        } else if utilization < 0.1 {
            recommendations.push(PerformanceRecommendation {
                category: "Network Utilization".to_string(),
                message: format!("网络利用率 ({:.1}%) 很低，有优化空间", utilization * 100.0),
                priority: "Low".to_string(),
                action: "可以增加批次大小 (max_aggregated_blocks_to_commit) 以提高效率".to_string(),
            });
        }

        // TPS 建议
        if tps < 10.0 {
            recommendations.push(PerformanceRecommendation {
                category: "Throughput".to_string(),
                message: format!("TPS ({:.1}) 较低，未充分利用 BSC 的高性能", tps),
                priority: "Medium".to_string(),
                action: "优化批处理参数和内存池配置以提高吞吐量".to_string(),
            });
        }

        // BSC 特定建议
        match self.l1_network {
            L1Network::BscMainnet => {
                if gas_price_gwei < 5.0 && utilization < 0.5 {
                    recommendations.push(PerformanceRecommendation {
                        category: "BSC Optimization".to_string(),
                        message: "网络条件良好，可以启用更激进的优化策略".to_string(),
                        priority: "Medium".to_string(),
                        action: "考虑启用 aggressive_batching 和降低 batch_overhead_l1_gas"
                            .to_string(),
                    });
                }
            }
            L1Network::BscTestnet => {
                recommendations.push(PerformanceRecommendation {
                    category: "Testnet Optimization".to_string(),
                    message: "测试网环境，可以使用更激进的参数进行测试".to_string(),
                    priority: "Low".to_string(),
                    action: "启用 fast_finality 和 aggressive_optimization".to_string(),
                });
            }
            _ => {}
        }

        recommendations
    }

    fn print_real_time_metrics(&self, metrics: &BscNetworkMetrics) {
        println!(
            "\n📊 实时网络指标 [{}]",
            chrono::DateTime::from_timestamp(metrics.timestamp as i64, 0)
                .unwrap_or_default()
                .format("%H:%M:%S")
        );

        println!("   区块高度: {}", metrics.block_number);
        println!("   区块时间: {:.1}s", metrics.block_time_seconds);
        println!("   Gas 价格: {:.2} Gwei", metrics.gas_price_gwei);
        println!("   网络利用率: {:.1}%", metrics.network_utilization * 100.0);
        println!("   TPS 估算: {:.1}", metrics.tps_estimate);
        println!("   性能评分: {:.1}/100", metrics.performance_score);

        if !metrics.recommendations.is_empty() {
            println!("   ⚠️  建议: {}", metrics.recommendations[0].message);
        }
    }

    /// 生成性能报告
    pub fn generate_performance_report(&self, metrics_history: &[BscNetworkMetrics]) -> String {
        if metrics_history.is_empty() {
            return "没有可用的性能数据".to_string();
        }

        let mut report = String::new();
        report.push_str("# BSC 网络性能报告\n\n");

        // 统计摘要
        let avg_block_time = metrics_history
            .iter()
            .map(|m| m.block_time_seconds)
            .sum::<f64>()
            / metrics_history.len() as f64;

        let avg_gas_price = metrics_history
            .iter()
            .map(|m| m.gas_price_gwei)
            .sum::<f64>()
            / metrics_history.len() as f64;

        let avg_utilization = metrics_history
            .iter()
            .map(|m| m.network_utilization)
            .sum::<f64>()
            / metrics_history.len() as f64;

        let avg_tps = metrics_history.iter().map(|m| m.tps_estimate).sum::<f64>()
            / metrics_history.len() as f64;

        let avg_performance = metrics_history
            .iter()
            .map(|m| m.performance_score)
            .sum::<f64>()
            / metrics_history.len() as f64;

        report.push_str(&format!("## 性能摘要\n"));
        report.push_str(&format!(
            "- 监控时长: {} 分钟\n",
            metrics_history.len() * 30 / 60
        ));
        report.push_str(&format!("- 平均区块时间: {:.2}s\n", avg_block_time));
        report.push_str(&format!("- 平均 Gas 价格: {:.2} Gwei\n", avg_gas_price));
        report.push_str(&format!(
            "- 平均网络利用率: {:.1}%\n",
            avg_utilization * 100.0
        ));
        report.push_str(&format!("- 平均 TPS: {:.1}\n", avg_tps));
        report.push_str(&format!("- 平均性能评分: {:.1}/100\n\n", avg_performance));

        // 优化建议汇总
        let mut all_recommendations = Vec::new();
        for metrics in metrics_history {
            all_recommendations.extend(metrics.recommendations.clone());
        }

        if !all_recommendations.is_empty() {
            report.push_str("## 优化建议\n");
            let mut recommendation_counts = std::collections::HashMap::new();
            for rec in &all_recommendations {
                *recommendation_counts.entry(&rec.message).or_insert(0) += 1;
            }

            let mut sorted_recs: Vec<_> = recommendation_counts.into_iter().collect();
            sorted_recs.sort_by(|a, b| b.1.cmp(&a.1));

            for (message, count) in sorted_recs.into_iter().take(5) {
                report.push_str(&format!("- {} (出现 {} 次)\n", message, count));
            }
        }

        report
    }
}
