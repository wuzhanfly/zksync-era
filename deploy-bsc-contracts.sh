#!/bin/bash

# BSC ZK Stack 合约部署脚本

set -e

echo "开始在BSC上部署ZK Stack合约..."

# 1. 设置环境变量
export PRIVATE_KEY="你的私钥"
export BSC_RPC_URL="https://bsc-dataseed1.binance.org/"
export ETHERSCAN_API_KEY="你的BSCScan API Key"

# 2. 编译合约
echo "编译合约..."
cd contracts/l1-contracts
yarn build:foundry

# 3. 部署L1核心合约
echo "部署L1核心合约..."
forge script deploy-scripts/DeployL1CoreContracts.s.sol \
    --rpc-url $BSC_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

# 4. 部署链类型管理器
echo "部署链类型管理器..."
forge script deploy-scripts/DeployCTM.s.sol \
    --rpc-url $BSC_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

# 5. 注册ZK链
echo "注册ZK链..."
forge script deploy-scripts/RegisterZKChain.s.sol \
    --rpc-url $BSC_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast

# 6. 验证部署结果
echo "验证部署结果..."
forge script deploy-scripts/VerifyDeployment.s.sol \
    --rpc-url $BSC_RPC_URL

echo "BSC ZK Stack合约部署完成！"
echo "请检查 script-out/output-deploy-l1.toml 获取部署地址"