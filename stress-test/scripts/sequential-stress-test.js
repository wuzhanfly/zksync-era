const { ethers } = require("hardhat");

async function main() {
  console.log("🔥 tMai Chain 顺序压力测试\n");

  const [signer] = await ethers.getSigners();
  console.log(`👤 测试账户: ${signer.address}`);
  
  const balance = await ethers.provider.getBalance(signer.address);
  console.log(`💰 账户余额: ${ethers.formatEther(balance)} tMai\n`);

  // 部署合约
  console.log("📋 部署压测合约...");
  const StressTest = await ethers.getContractFactory("StressTest");
  const stressTest = await StressTest.deploy();
  await stressTest.waitForDeployment();
  const contractAddress = await stressTest.getAddress();
  console.log(`✅ 合约地址: ${contractAddress}\n`);

  // 配置
  const config = {
    warmup: 3,       // 预热交易数
    rounds: 3,       // 测试轮数
    txPerRound: 20,  // 每轮交易数
  };

  console.log("⚙️  测试配置:");
  console.log(`   预热: ${config.warmup} 笔`);
  console.log(`   轮数: ${config.rounds} 轮`);
  console.log(`   每轮: ${config.txPerRound} 笔`);
  console.log(`   模式: 顺序发送（避免 nonce 冲突）\n`);

  // 预热
  console.log("🔥 预热阶段...");
  for (let i = 0; i < config.warmup; i++) {
    try {
      const tx = await stressTest.increment();
      await tx.wait();
      console.log(`   ✅ ${i + 1}/${config.warmup}`);
    } catch (err) {
      console.log(`   ❌ ${i + 1}/${config.warmup} 失败: ${err.message.substring(0, 50)}`);
    }
  }
  console.log("");

  // 压力测试
  const results = [];
  
  for (let round = 1; round <= config.rounds; round++) {
    console.log(`📊 第 ${round}/${config.rounds} 轮测试`);
    console.log("─".repeat(50));
    
    const start = Date.now();
    let successful = 0;
    let failed = 0;
    const latencies = [];
    
    // 顺序发送交易
    for (let i = 0; i < config.txPerRound; i++) {
      const txStart = Date.now();
      try {
        const tx = await stressTest.increment();
        const receipt = await tx.wait();
        const txDuration = Date.now() - txStart;
        latencies.push(txDuration);
        successful++;
        
        console.log(`   ✅ ${i + 1}/${config.txPerRound} - ${txDuration}ms - Gas: ${receipt.gasUsed.toString()}`);
      } catch (err) {
        failed++;
        const txDuration = Date.now() - txStart;
        console.log(`   ❌ ${i + 1}/${config.txPerRound} - ${txDuration}ms - ${err.message.substring(0, 40)}`);
      }
    }
    
    const duration = Date.now() - start;
    const tps = (successful / (duration / 1000)).toFixed(2);
    const avgLatency = latencies.length > 0 
      ? (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(2)
      : 0;
    const minLatency = latencies.length > 0 ? Math.min(...latencies) : 0;
    const maxLatency = latencies.length > 0 ? Math.max(...latencies) : 0;
    
    const result = {
      round,
      total: config.txPerRound,
      successful,
      failed,
      duration,
      tps,
      avgLatency,
      minLatency,
      maxLatency,
    };
    
    results.push(result);
    
    console.log(`\n   ✅ 成功: ${successful}/${config.txPerRound} (${(successful/config.txPerRound*100).toFixed(1)}%)`);
    console.log(`   ❌ 失败: ${failed}`);
    console.log(`   ⏱️  总耗时: ${duration}ms (${(duration/1000).toFixed(2)}s)`);
    console.log(`   🚀 TPS: ${tps}`);
    console.log(`   📊 延迟: 平均 ${avgLatency}ms | 最小 ${minLatency}ms | 最大 ${maxLatency}ms\n`);
    
    // 轮次间隔
    if (round < config.rounds) {
      console.log("⏸️  等待 2 秒...\n");
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }

  // 汇总报告
  console.log("=".repeat(60));
  console.log("📈 压力测试汇总报告");
  console.log("=".repeat(60));
  
  const totalTx = results.reduce((sum, r) => sum + r.total, 0);
  const totalSuccessful = results.reduce((sum, r) => sum + r.successful, 0);
  const totalFailed = results.reduce((sum, r) => sum + r.failed, 0);
  const avgTps = (results.reduce((sum, r) => sum + parseFloat(r.tps), 0) / results.length).toFixed(2);
  const avgLatency = (results.reduce((sum, r) => sum + parseFloat(r.avgLatency), 0) / results.length).toFixed(2);
  const maxTps = Math.max(...results.map(r => parseFloat(r.tps))).toFixed(2);
  const minTps = Math.min(...results.map(r => parseFloat(r.tps))).toFixed(2);
  
  console.log(`\n总交易数: ${totalTx}`);
  console.log(`成功: ${totalSuccessful} (${(totalSuccessful/totalTx*100).toFixed(2)}%)`);
  console.log(`失败: ${totalFailed} (${(totalFailed/totalTx*100).toFixed(2)}%)`);
  console.log(`\n平均 TPS: ${avgTps}`);
  console.log(`最高 TPS: ${maxTps}`);
  console.log(`最低 TPS: ${minTps}`);
  console.log(`平均延迟: ${avgLatency}ms`);
  
  console.log("\n" + "=".repeat(60));
  
  // 详细数据
  console.log("\n📋 各轮详细数据:\n");
  console.log("轮次 | 成功率 | TPS   | 平均延迟 | 最小延迟 | 最大延迟");
  console.log("-----|--------|-------|----------|----------|----------");
  results.forEach(r => {
    const successRate = (r.successful / r.total * 100).toFixed(1);
    console.log(`  ${r.round}  | ${successRate.padStart(5)}% | ${r.tps.padStart(5)} | ${r.avgLatency.padStart(6)}ms | ${r.minLatency.toString().padStart(6)}ms | ${r.maxLatency.toString().padStart(6)}ms`);
  });
  
  console.log("\n✅ 测试完成！\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
