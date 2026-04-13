const { ethers } = require('ethers');

async function main() {
  console.log('🔥 简单压力测试（纯 ethers.js）\n');
  
  const provider = new ethers.JsonRpcProvider('http://54.255.184.251:3050');
  const privateKey = '0xc9fd9d8eedf1d07a3ff46bd7370c48db3b4c359f4d0dfd73404c3a27f687dae1';
  const wallet = new ethers.Wallet(privateKey, provider);
  
  console.log(`👤 测试账户: ${wallet.address}`);
  const balance = await provider.getBalance(wallet.address);
  console.log(`💰 账户余额: ${ethers.formatEther(balance)} tMai\n`);
  
  // 使用已部署的合约
  const contractAddress = '0x1aa5CB2A98d24c94edEa42F514564D566ffEBFEe';
  const abi = [
    'function increment() public',
    'function counter() public view returns (uint256)'
  ];
  
  const contract = new ethers.Contract(contractAddress, abi, wallet);
  
  console.log(`📋 使用合约: ${contractAddress}\n`);
  
  // 测试配置
  const rounds = 3;
  const txPerRound = 20;
  
  console.log(`⚙️  配置: ${rounds} 轮 x ${txPerRound} 笔\n`);
  
  const results = [];
  
  for (let round = 1; round <= rounds; round++) {
    console.log(`📊 第 ${round}/${rounds} 轮`);
    console.log('─'.repeat(50));
    
    const start = Date.now();
    let successful = 0;
    let failed = 0;
    const latencies = [];
    
    for (let i = 0; i < txPerRound; i++) {
      const txStart = Date.now();
      try {
        const tx = await contract.increment({
          gasLimit: 200000
        });
        const receipt = await tx.wait();
        const txDuration = Date.now() - txStart;
        latencies.push(txDuration);
        successful++;
        
        console.log(`   ✅ ${i + 1}/${txPerRound} - ${txDuration}ms - Gas: ${receipt.gasUsed}`);
      } catch (err) {
        failed++;
        const txDuration = Date.now() - txStart;
        console.log(`   ❌ ${i + 1}/${txPerRound} - ${err.message.substring(0, 50)}`);
      }
    }
    
    const duration = Date.now() - start;
    const tps = (successful / (duration / 1000)).toFixed(2);
    const avgLatency = latencies.length > 0 
      ? (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(2)
      : 0;
    
    results.push({ round, successful, failed, duration, tps, avgLatency });
    
    console.log(`\n   ✅ 成功: ${successful}/${txPerRound} (${(successful/txPerRound*100).toFixed(1)}%)`);
    console.log(`   ⏱️  耗时: ${(duration/1000).toFixed(2)}s`);
    console.log(`   🚀 TPS: ${tps}`);
    console.log(`   📊 平均延迟: ${avgLatency}ms\n`);
    
    if (round < rounds) {
      console.log('⏸️  等待 2 秒...\n');
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
  
  // 汇总
  console.log('='.repeat(60));
  console.log('📈 测试汇总');
  console.log('='.repeat(60));
  
  const totalSuccessful = results.reduce((sum, r) => sum + r.successful, 0);
  const totalFailed = results.reduce((sum, r) => sum + r.failed, 0);
  const avgTps = (results.reduce((sum, r) => sum + parseFloat(r.tps), 0) / results.length).toFixed(2);
  const maxTps = Math.max(...results.map(r => parseFloat(r.tps))).toFixed(2);
  
  console.log(`\n总交易: ${totalSuccessful + totalFailed}`);
  console.log(`成功: ${totalSuccessful} (${(totalSuccessful/(totalSuccessful+totalFailed)*100).toFixed(1)}%)`);
  console.log(`失败: ${totalFailed}`);
  console.log(`\n平均 TPS: ${avgTps}`);
  console.log(`最高 TPS: ${maxTps}\n`);
  
  console.log('✅ 测试完成！\n');
}

main().catch(console.error);
