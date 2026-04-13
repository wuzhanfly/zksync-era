#!/bin/bash

echo "🔥 tMai Chain 压力测试工具"
echo "================================"
echo ""

# 检查是否安装了 hardhat
if ! npm list hardhat &> /dev/null; then
    echo "📦 安装 Hardhat 依赖..."
    npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
fi

# 检查 .env.tmai 文件
if [ ! -f .env.tmai ]; then
    echo "❌ 错误: .env.tmai 文件不存在"
    echo "请创建 .env.tmai 文件并设置 PRIVATE_KEY"
    exit 1
fi

echo "🚀 开始压力测试..."
echo ""

# 运行测试
npx hardhat test test/stress-test.js --network tmaiChain

echo ""
echo "✅ 压力测试完成！"
