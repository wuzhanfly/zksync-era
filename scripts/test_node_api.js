const { ethers } = require('ethers');

async function testAPI() {
  console.log('🔍 测试 tMai Chain API\n');
  
  const provider = new ethers.JsonRpcProvider('http://54.255.184.251:3050');
  
  try {
    // 1. 测试连接
    console.log('1️⃣ 测试网络连接...');
    const network = await provider.getNetwork();
    console.log(`   ✅ Chain ID: ${network.chainId}`);
    
    // 2. 获取区块号
    console.log('\n2️⃣ 获取最新区块...');
    const blockNumber = await provider.getBlockNumber();
    console.log(`   ✅ Block Number: ${blockNumber}`);
    
    // 3. 获取区块详情
    console.log('\n3️⃣ 获取区块详情...');
    const block = await provider.getBlock(blockNumber);
    console.log(`   ✅ Block Hash: ${block.hash}`);
    console.log(`   ✅ Transactions: ${block.transactions.length}`);
    console.log(`   ✅ Timestamp: ${new Date(block.timestamp * 1000).toISOString()}`);
    
    // 4. 测试账户余额
    console.log('\n4️⃣ 查询账户余额...');
    const address = '0x7CB5c1C44f7729a34F07Bb67603d65D81a8cD16a';
    const balance = await provider.getBalance(address);
    console.log(`   ✅ Balance: ${ethers.formatEther(balance)} tMai`);
    
    // 5. 获取 Gas Price
    console.log('\n5️⃣ 获取 Gas Price...');
    const feeData = await provider.getFeeData();
    console.log(`   ✅ Gas Price: ${feeData.gasPrice} wei`);
    console.log(`   ✅ Max Fee: ${feeData.maxFeePerGas} wei`);
    
    console.log('\n✅ 所有测试通过！节点运行正常。\n');
    
  } catch (error) {
    console.error('\n❌ 测试失败:', error.message);
    console.error('\n可能原因:');
    console.error('  1. 节点正在重启');
    console.error('  2. 网络连接问题');
    console.error('  3. 节点负载过高');
    process.exit(1);
  }
}

testAPI();
