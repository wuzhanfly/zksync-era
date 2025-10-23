#!/bin/bash

# 设置BSC环境变量
export L1_CHAIN_ID=97
export L1_RPC_URL="http://47.130.24.70:10575"

echo "🔧 测试BSC生态系统初始化..."
echo "L1_CHAIN_ID: $L1_CHAIN_ID"
echo "L1_RPC_URL: $L1_RPC_URL"

# 进入zkstack_cli目录并运行
cd zkstack_cli

echo "🚀 开始运行zkstack ecosystem init..."
./target/release/zkstack ecosystem init \
    --l1-rpc-url "http://47.130.24.70:10575" \
    --server-db-url "postgres://postgres:notsecurepassword@localhost:5432" \
    --server-db-name "zk_bsc_test" \
    --deploy-ecosystem true \
    --deploy-erc20 true \
    --deploy-paymaster true \
    --timeout 600 \
    --retries 5 \
    --observability true