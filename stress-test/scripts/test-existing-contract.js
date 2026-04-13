const { ethers } = require("hardhat");

async function main() {
  console.log("🔥 使用已部署合约测试 TPS\n");

  const [signer] = await ethers.getSigners();
  console.log(`👤 测试账户: ${signer.address}`);
  
  const balance = await ethers.provider.getBalance(signer.address);
  console.log(`💰 账户余额: ${ethers.formatEther(balance)} tMai\n`);

  // 使用之前部署的合约
  const contractAddress = "0x1aa5CB2A98d24c94edEa42F514564D566ffEBFEe";
  console.log(`📋 使用合约: ${contractAddress}\n`);

  const StressTest = await ethers.getContractFactory("StressTest");
  const stressTest = StressTest.attach(contractAddress);

  // 配置
  const config = {
    rounds: 3,
    txPerRound: 20,
  };

  console.log("⚙️  测试配置:");
  console.log(`   轮数: ${config.rounds} 轮`);
  console.log(`   每轮: ${config.txPerRound} 笔\n`);

  const results = [];
  
  for (let round = 1; round <= config.rounds; round++) {
    console.log(`📊 第 ${round}/${config.rounds} 轮测试`);
    console.log("─".repeat(50));
    
    const start = Date.now();
    let successful = 0;
    let failed = 0;
    const latencies = [];
    
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
    
    results.push({
      round,
      successful,
      failed,
      duration,
      tps,
      avgLatency,
    });
    
    console.log(`\n   ✅ 成功: ${successful}/${config.txPerRound}`);
    console.log(`   ⏱️  总耗时: ${duration}ms (${(duration/1000).toFixed(2)}s)`);
    console.log(`   🚀 TPS: ${tps}`);
    console.log(`   📊 平均延迟: ${avgLatency}ms\n`);
    
    if (round < config.rounds) {
      console.log("⏸️  等待 2 秒...\n");
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }

  // 汇总
  console.log("=".repeat(60));
  console.log("📈 测试汇总");
  console.log("=".repeat(60));
  
  const totalSuccessful = results.reduce((sum, r) => sum + r.successful, 0);
  const totalFailed = results.reduce((sum, r) => sum + r.failed, 0);
  const avgTps = (results.reduce((sum, r) => sum + parseFloat(r.tps), 0) / results.length).toFixed(2);
  
  console.log(`\n总交易数: ${totalSuccessful + totalFailed}`);
  console.log(`成功: ${totalSuccessful} (${(totalSuccessful/(totalSuccessful+totalFailed)*100).toFixed(2)}%)`);
  console.log(`失败: ${totalFailed}`);
  console.log(`平均 TPS: ${avgTps}\n`);
  
  console.log("✅ 测试完成！\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
