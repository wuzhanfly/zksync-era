#!/bin/bash

# BSC测试网ZK Stack部署脚本

set -e

echo "🚀 开始BSC测试网ZK Stack部署..."

# 检查环境
if [ ! -f "contracts/.env.bsc.production" ]; then
    echo "❌ 配置文件不存在，请先创建 contracts/.env.bsc.production"
    exit 1
fi

# 设置环境变量
export $(cat contracts/.env.bsc.production | xargs)
export HARDHAT_NETWORK=bscTestnet

echo "📋 部署配置:"
echo "  网络: BSC测试网 (Chain ID: 97)"
echo "  部署者: $DEPLOYER_ADDRESS"
echo "  治理管理员: $GOVERNANCE_ADMIN_ADDRESS"
echo "  安全委员会: $GOVERNANCE_SECURITY_COUNCIL_ADDRESS"
echo "  链管理员: $CHAIN_ADMIN_ADDRESS"

# 检查余额
echo "💰 检查部署者余额..."
cd contracts
node -e "
const { ethers } = require('hardhat');
async function checkBalance() {
    const provider = new ethers.providers.JsonRpcProvider('$BSC_TESTNET_RPC');
    const balance = await provider.getBalance('$DEPLOYER_ADDRESS');
    console.log('部署者余额:', ethers.utils.formatEther(balance), 'BNB');
    if (balance.lt(ethers.utils.parseEther('0.1'))) {
        console.log('⚠️  余额不足，请从水龙头获取测试网BNB');
        console.log('水龙头地址: https://testnet.bnbchain.org/faucet-smart');
        process.exit(1);
    }
}
checkBalance().catch(console.error);
"

echo "🔨 编译合约..."
yarn l1 build:foundry
yarn l2 compile

echo "📦 部署L1核心合约..."
cd l1-contracts
forge script deploy-scripts/DeployL1CoreContracts.s.sol \
    --network bscTestnet \
    --broadcast \
    --verify \
    --etherscan-api-key $BSCSCAN_API_KEY \
    -vvv

echo "🏗️ 部署链类型管理器..."
forge script deploy-scripts/DeployCTM.s.sol \
    --network bscTestnet \
    --broadcast \
    --verify \
    --etherscan-api-key $BSCSCAN_API_KEY \
    -vvv

echo "🔗 注册ZK链..."
forge script deploy-scripts/RegisterZKChain.s.sol \
    --network bscTestnet \
    --broadcast \
    -vvv

echo "✅ 验证部署..."
forge script deploy-scripts/VerifyDeployment.s.sol \
    --network bscTestnet \
    -vvv

echo "📄 生成部署报告..."
if [ -f "script-out/output-deploy-l1.toml" ]; then
    echo "📋 部署地址:"
    cat script-out/output-deploy-l1.toml
else
    echo "⚠️  部署输出文件未找到"
fi

echo ""
echo "🎉 BSC测试网ZK Stack部署完成！"
echo ""
echo "📚 下一步:"
echo "  1. 检查部署地址: cat contracts/l1-contracts/script-out/output-deploy-l1.toml"
echo "  2. 验证合约: yarn verify:bsc-testnet"
echo "  3. 运行测试: yarn test:integration --network bscTestnet"
echo "  4. 查看治理指南: contracts/ZK_STACK_GOVERNANCE_GUIDE.md"
echo ""
echo "🔗 有用链接:"
echo "  BSC测试网浏览器: https://testnet.bscscan.com"
echo "  BSC测试网水龙头: https://testnet.bnbchain.org/faucet-smart"