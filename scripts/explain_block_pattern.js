const { ethers } = require('ethers');

async function analyzeBlockPattern() {
  console.log('🔍 区块模式分析\n');
  
  const provider = new ethers.JsonRpcProvider('http://54.255.184.251:3050');
  
  try {
    const currentBlock = await provider.getBlockNumber();
    console.log(`当前区块高度: ${currentBlock}\n`);
    
    // 分析最近 20 个区块
    console.log('📊 最近 20 个区块分析:');
    console.log('='.repeat(70));
    
    const blocks = [];
    for (let i = 19; i >= 0; i--) {
      const blockNum = currentBlock - i;
      const block = await provider.getBlock(blockNum);
      blocks.push({
        number: blockNum,
        txCount: block.transactions.length,
        timestamp: block.timestamp
      });
    }
    
    // 显示区块模式
    let emptyBlocks = 0;
    let singleTxBlocks = 0;
    let multiTxBlocks = 0;
    
    blocks.forEach((block, idx) => {
      const txCount = block.txCount;
      let visual = '';
      
      if (txCount === 0) {
        visual = '⚪'.repeat(1);
        emptyBlocks++;
      } else if (txCount === 1) {
        visual = '🟡'.repeat(1);
        singleTxBlocks++;
      } else if (txCount < 10) {
        visual = '🟠'.repeat(Math.min(txCount, 10));
        multiTxBlocks++;
      } else {
        visual = '🔴'.repeat(10) + ` (${txCount})`;
        multiTxBlocks++;
      }
      
      const timeDiff = idx > 0 ? block.timestamp - blocks[idx - 1].timestamp : 0;
      
      console.log(
        `#${block.number.toString().padStart(6)} | ` +
        `${visual.padEnd(20)} | ` +
        `${txCount.toString().padStart(3)} 笔 | ` +
        `+${timeDiff}s`
      );
    });
    
    console.log('='.repeat(70));
    console.log('\n📈 统计:');
    console.log(`   空区块 (⚪): ${emptyBlocks} (${(emptyBlocks/20*100).toFixed(0)}%)`);
    console.log(`   单笔交易 (🟡): ${singleTxBlocks} (${(singleTxBlocks/20*100).toFixed(0)}%)`);
    console.log(`   多笔交易 (🟠🔴): ${multiTxBlocks} (${(multiTxBlocks/20*100).toFixed(0)}%)`);
    
    console.log('\n💡 解释:');
    console.log('─'.repeat(70));
    
    if (emptyBlocks > 10 && singleTxBlocks > 5) {
      console.log('✅ 当前模式: 低频交易模式');
      console.log('');
      console.log('这是正常现象！原因:');
      console.log('  1. miniblock_commit_deadline_ms = 1000ms');
      console.log('     → 每 1 秒封装一个区块');
      console.log('  2. 手动发送交易间隔 > 1 秒');
      console.log('     → 每个区块只能包含 1 笔交易');
      console.log('  3. 没有交易时 → 产生空区块');
      console.log('');
      console.log('🚀 要测试真实 TPS，需要运行高频压力测试:');
      console.log('   node scripts/simple_stress_test.js');
      console.log('');
      console.log('在压力测试下，你会看到:');
      console.log('  • 每个区块包含多笔交易 (🟠🔴)');
      console.log('  • 更少的空区块');
      console.log('  • 真实的 TPS 性能');
    } else if (multiTxBlocks > 10) {
      console.log('🔥 当前模式: 高频交易模式');
      console.log('');
      console.log('区块正在高效打包多笔交易！');
      console.log('这说明你的优化配置正在生效。');
    } else {
      console.log('⚠️  当前模式: 混合模式');
      console.log('');
      console.log('有一些高频交易，但不够持续。');
    }
    
    console.log('─'.repeat(70));
    
  } catch (error) {
    console.error('❌ 分析失败:', error.message);
  }
}

analyzeBlockPattern().catch(console.error);
