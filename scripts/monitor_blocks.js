const { ethers } = require('ethers');

async function monitorBlocks() {
  console.log('👀 实时监控区块生产\n');
  console.log('按 Ctrl+C 停止监控\n');
  console.log('='.repeat(80));
  
  const provider = new ethers.JsonRpcProvider('http://54.255.184.251:3050');
  
  let lastBlockNumber = await provider.getBlockNumber();
  let lastTimestamp = Date.now();
  
  console.log(`起始区块: ${lastBlockNumber}\n`);
  
  provider.on('block', async (blockNumber) => {
    try {
      const block = await provider.getBlock(blockNumber);
      const now = Date.now();
      const timeDiff = ((now - lastTimestamp) / 1000).toFixed(2);
      lastTimestamp = now;
      
      const txCount = block.transactions.length;
      const blockTime = new Date(block.timestamp * 1000).toLocaleTimeString('zh-CN');
      
      let emoji = '📦';
      if (txCount === 0) emoji = '⚪';
      else if (txCount === 1) emoji = '🟡';
      else if (txCount < 10) emoji = '🟠';
      else emoji = '🔴';
      
      console.log(
        `${emoji} 区块 #${blockNumber.toString().padStart(6)} | ` +
        `交易: ${txCount.toString().padStart(3)} | ` +
        `间隔: ${timeDiff.padStart(5)}s | ` +
        `时间: ${blockTime}`
      );
      
      lastBlockNumber = blockNumber;
    } catch (error) {
      console.error(`❌ 获取区块 ${blockNumber} 失败:`, error.message);
    }
  });
  
  // 保持进程运行
  process.on('SIGINT', () => {
    console.log('\n\n👋 停止监控');
    process.exit(0);
  });
}

monitorBlocks().catch(console.error);
