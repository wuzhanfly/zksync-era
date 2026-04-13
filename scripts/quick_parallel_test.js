const { ethers } = require('ethers');

async function main() {
  console.log('⚡ 快速并发测试\n');
  
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
  
  // 测试配置 - 减少到10笔
  const totalTx = 10;
  
  console.log(`⚙️  配置: ${totalTx} 笔交易 (并发发送)\n`);
  console.log('📊 开始测试');
  console.log('─'.repeat(50));
  
  const start = Date.now();
  
  // 获取起始nonce
  const baseNonce = await wallet.getNonce();
  console.log(`   起始 nonce: ${baseNonce}`);
  console.log(`   发送 ${totalTx} 笔交易...\n`);
  
  const promises = [];
  
  // 并发发送所有交易
  for (let i = 0; i < totalTx; i++) {
    const txNonce = baseNonce + i;
    const txStart = Date.now();
    
    const promise = (async () => {
      try {
        const tx = await contract.increment({
          gasLimit: 200000,
          nonce: txNonce
        });
        
        console.log(`   ✅ 交易 #${i + 1} 已发送 (nonce: ${txNonce}, hash: ${tx.hash.substring(0, 10)}...)`);
        
        const receipt = await tx.wait();
        const txDuration = Date.now() - txStart;
        
        console.log(`   ✅ 交易 #${i + 1} 已确认 - ${txDuration}ms - Gas: ${receipt.gasUsed}`);
        
        return {
          success: true,
          duration: txDuration,
          gasUsed: receipt.gasUsed.toString(),
          nonce: txNonce,
          index: i + 1
        };
      } catch (err) {
        console.log(`   ❌ 交易 #${i + 1} 失败 (nonce: ${txNonce}): ${err.message.substring(0, 50)}`);
        return {
          success: false,
          duration: Date.now() - txStart,
          error: err.message,
          nonce: txNonce,
          index: i + 1
        };
      }
    })();
    
    promises.push(promise);
    
    // 每笔交易间隔50ms，避免瞬间发送太多
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  
  console.log(`\n   等待所有交易确认...\n`);
  
  // 等待所有交易完成
  const txResults = await Promise.all(promises);
  
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
  
  console.log('\n✅ 测试完成！\n');
}

main().catch(console.error);
