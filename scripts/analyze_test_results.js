const testResults = `
交易 #2 已发送 (nonce: 117, hash: 0x2af81ccb...)
交易 #3 已发送 (nonce: 118, hash: 0x20f11dc4...)
交易 #4 已发送 (nonce: 119, hash: 0xa52ba067...)
交易 #5 已发送 (nonce: 120, hash: 0x7da98f2f...)
交易 #6 已发送 (nonce: 121, hash: 0x7068523a...)
交易 #7 已发送 (nonce: 122, hash: 0x00612d72...)
交易 #8 已发送 (nonce: 123, hash: 0x6cd23d26...)
交易 #9 已发送 (nonce: 124, hash: 0x409c0929...)
交易 #10 已发送 (nonce: 125, hash: 0x36b84279...)

交易 #2 已确认 - 19314ms - Gas: 162983
交易 #3 已确认 - 42221ms - Gas: 162989
交易 #4 已确认 - 63543ms - Gas: 162989
交易 #5 已确认 - 83249ms - Gas: 162983
交易 #6 已确认 - 99587ms - Gas: 162989
交易 #7 已确认 - 116751ms - Gas: 162989
交易 #8 已确认 - 137738ms - Gas: 162983
交易 #9 已确认 - 168157ms - Gas: 162983
`;

console.log('📊 交易处理时间分析');
console.log('='.repeat(70));
console.log('');

const txData = [
  { num: 2, time: 19314, gas: 162983 },
  { num: 3, time: 42221, gas: 162989 },
  { num: 4, time: 63543, gas: 162989 },
  { num: 5, time: 83249, gas: 162983 },
  { num: 6, time: 99587, gas: 162989 },
  { num: 7, time: 116751, gas: 162989 },
  { num: 8, time: 137738, gas: 162983 },
  { num: 9, time: 168157, gas: 162983 },
];

console.log('交易确认时间（从发送到确认）:');
console.log('-'.repeat(70));
txData.forEach((tx, idx) => {
  const prevTime = idx > 0 ? txData[idx - 1].time : 0;
  const delta = tx.time - prevTime;
  const perTx = (tx.time / tx.num).toFixed(0);
  
  console.log(
    `交易 #${tx.num}: ${(tx.time/1000).toFixed(1)}s | ` +
    `增量: +${(delta/1000).toFixed(1)}s | ` +
    `平均: ${(perTx/1000).toFixed(1)}s/笔`
  );
});

console.log('');
console.log('📈 统计分析:');
console.log('-'.repeat(70));

const deltas = [];
for (let i = 1; i < txData.length; i++) {
  deltas.push(txData[i].time - txData[i-1].time);
}

const avgDelta = deltas.reduce((a, b) => a + b, 0) / deltas.length;
const minDelta = Math.min(...deltas);
const maxDelta = Math.max(...deltas);

console.log(`平均处理时间（每笔）: ${(avgDelta/1000).toFixed(2)}s`);
console.log(`最快处理时间: ${(minDelta/1000).toFixed(2)}s`);
console.log(`最慢处理时间: ${(maxDelta/1000).toFixed(2)}s`);
console.log(`总耗时: ${(txData[txData.length-1].time/1000).toFixed(1)}s`);
console.log(`实际TPS: ${(txData.length / (txData[txData.length-1].time/1000)).toFixed(3)}`);

console.log('');
console.log('🔍 结论:');
console.log('-'.repeat(70));
console.log('1. 交易是顺序处理的（每笔约20-23秒）');
console.log('2. 即使并发发送，节点也按nonce顺序执行');
console.log('3. 第N笔交易的确认时间 ≈ N × 20秒');
console.log('4. 2核4G服务器处理单笔交易需要约20秒');
console.log('');
console.log('💡 时间分解（推测）:');
console.log('   - VM执行（ZK proof）: ~10-12s');
console.log('   - 数据库写入: ~3-5s');
console.log('   - 状态更新: ~2-3s');
console.log('   - 其他开销: ~2-3s');
console.log('');
