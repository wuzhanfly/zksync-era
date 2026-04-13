const { ethers } = require('ethers');

async function main() {
  console.log('🚀 并发压力测试\n');
  
  const provider = new ethers.JsonRpcProvider('http://54.255.184.251:3050');
  const privateKey = '0xc9fd9d8eedf1d07a3ff46bd7370c48db3b4c359f4d0dfd73404c3a27f687dae1';
  const wallet = new ethers.Wallet(privateKey, provider);
  
  console.log(`👤 测试账户: ${wallet.address}`);
  const balance = await provider.getBalance(wallet.address);
  console.log(`💰 账户余额: ${ethers.formatEther(balance)} tMai\n`);
  
  const contractAddress = '0x1aa5CB2A98d24c94edEa42F514564D566ffEBFEe';
  const abi = [
    'function increment() public',
    'function counter() public view returns (uint256)'
  ];
  
  const contract = new ethers.Contract(contractAddress, abi, wallet);
  
  console.log(`📋 使用合约: ${contractAddress}\n`);
  
  // 测试配置
  const totalTx = 50;
  const batchSize = 10; // 每批发送10笔
  
  console.log(`⚙️  配置: ${totalTx} 笔交易, 每批 ${batchSize} 笔\n`);
  console.log('📊 开始测试');
  console.log('─'.repeat(50));
  
  const start = Date.now();
  const txResults = [];
  
  // 获取起始nonce
  let baseNonce = await wallet.getNonce();
  console.log(`   起始 nonce: ${baseNonce}\n`);
  
  // 分批发送交易
  for (let batch = 0; batch < Math.ceil(totalTx / batchSize); batch++) {
    const batchStart = batch * batchSize;
    const batchEnd = Math.min(batchStart + batchSize, totalTx);
    const batchCount = batchEnd - batchStart;
    
    console.log(`   批次 ${batch + 1}: 发送交易 ${batchStart + 1}-${batchEnd}...`);
    
    const promises = [];
    
    for (let i = 0; i < batchCount; i++) {
      const txIndex = batchStart + i;
      const txNonce = baseNonce + txIndex;
      const txStart = Date.now();
      
      const promise = (async () => {
        try {
          const tx = await contract.increment({
            gasLimit: 200000,
            nonce: txNonce
          });
          
          const receipt = await tx.wait();
          const txDuration = Date.now() - txStart;
          
          return {
            success: true,
            duration: txDuration,
            gasUsed: receipt.gasUsed.toString(),
            nonce: txNonce,
            hash: tx.hash,
            index: txIndex + 1
          };
        } catch (err) {
          return {
            success: false,
            duration: Date.now() - txStart,
            error: err.message,
            nonce: txNonce,
            index: txIndex + 1
          };
        }
      })();
      
      promises.push(promise);
    }
    
    // 等待当前批次完成
    const batchResults = await Promise.all(promises);
    txResults.push(...batchResults);
    
    const batchSuccess = batchResults.filter(r => r.success).length;
    console.log(`   批次 ${batch + 1}: 完成 ${batchSuccess}/${batchCount} 笔\n`);
    
    // 批次间短暂延迟
    if (batch < Math.ceil(totalTx / batchSize) - 1) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }
  
  const duration = Date.now() - start;
  
  // 统计结果
  const successful = txResults.filter(r => r.success).length;
  const failed = txResults.filter(r => !r.success).length;
  const latencies = txResults.filter(r => r.success).map(r => r.duration);
  
  const tps = (successful / (duration / 1000)).toFixed(2);
  const avgLatency = latencies.length > 0 
    ? (latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(2)
    : 0;
  const minLatency = latencies.length > 0 ? Math.min(...latencies) : 0;
  const maxLatency = latencies.length > 0 ? Math.max(...latencies) : 0;
  
  console.log('='.repeat(60));
  console.log('📈 测试结果');
  console.log('='.repeat(60));
  
  console.log(`\n✅ 成功: ${successful}/${totalTx} (${(successful/totalTx*100).toFixed(1)}%)`);
  console.log(`❌ 失败: ${failed}`);
  console.log(`⏱️  总耗时: ${(duration/1000).toFixed(2)}s`);
  console.log(`🚀 TPS: ${tps}`);
  console.log(`📊 延迟: 平均 ${avgLatency}ms, 最小 ${minLatency}ms, 最大 ${maxLatency}ms`);
  
  // 显示失败的交易
  if (failed > 0) {
    console.log(`\n❌ 失败交易详情:`);
    txResults.filter(r => !r.success).forEach(r => {
      console.log(`   #${r.index} (nonce ${r.nonce}): ${r.error.substring(0, 80)}`);
    });
  }
  
  console.log('\n✅ 测试完成！\n');
}

main().catch(console.error);
