#!/bin/bash

# 从 ZKsync 日志中提取操作员地址的脚本

set -e

echo "🔍 从日志中提取操作员地址信息..."

LOG_FILE=${1:-"logs/zksync_server.log"}

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ 日志文件不存在: $LOG_FILE"
    echo "💡 使用方法: $0 [日志文件路径]"
    echo "💡 默认路径: logs/zksync_server.log"
    exit 1
fi

echo "📂 分析日志文件: $LOG_FILE"
echo ""

# 提取操作员地址
echo "🏷️  操作员地址信息:"
echo "===================="

# 从发送交易的日志中提取地址
OPERATOR_ADDRESSES=$(grep -o "operator_address 0x[a-fA-F0-9]\{40\}" "$LOG_FILE" | sort | uniq)

if [ -n "$OPERATOR_ADDRESSES" ]; then
    echo "$OPERATOR_ADDRESSES" | while read -r line; do
        ADDRESS=$(echo "$line" | cut -d' ' -f2)
        echo "📍 发现操作员地址: $ADDRESS"
        
        # 检查这个地址的余额
        echo "   💰 检查余额..."
        BSC_RPC="https://data-seed-prebsc-1-s1.binance.org:8545"
        
        BALANCE_HEX=$(curl -s -X POST -H "Content-Type: application/json" \
          --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$ADDRESS\",\"latest\"],\"id\":1}" \
          $BSC_RPC | jq -r '.result' 2>/dev/null)
        
        if [ "$BALANCE_HEX" != "null" ] && [ -n "$BALANCE_HEX" ]; then
            BALANCE_WEI=$((16#${BALANCE_HEX#0x}))
            BALANCE_BNB=$(echo "scale=6; $BALANCE_WEI / 1000000000000000000" | bc -l 2>/dev/null || echo "计算错误")
            echo "   💰 余额: $BALANCE_BNB BNB ($BALANCE_WEI wei)"
            
            # 检查是否足够
            MIN_BALANCE_WEI=10000000000000000  # 0.01 BNB
            if [ $BALANCE_WEI -lt $MIN_BALANCE_WEI ]; then
                echo "   ⚠️  余额不足！需要充值"
            else
                echo "   ✅ 余额充足"
            fi
        else
            echo "   ❌ 无法获取余额"
        fi
        echo ""
    done
else
    echo "❌ 未找到操作员地址信息"
    echo "💡 请确保日志包含发送交易的记录"
fi

# 提取 insufficient funds 错误
echo ""
echo "💸 资金不足错误分析:"
echo "===================="

INSUFFICIENT_FUNDS_ERRORS=$(grep -n "insufficient funds" "$LOG_FILE" | head -10)

if [ -n "$INSUFFICIENT_FUNDS_ERRORS" ]; then
    echo "$INSUFFICIENT_FUNDS_ERRORS" | while read -r line; do
        LINE_NUM=$(echo "$line" | cut -d':' -f1)
        echo "📍 第 $LINE_NUM 行发现资金不足错误"
        
        # 查找同一行或附近行的操作员地址
        CONTEXT=$(sed -n "$((LINE_NUM-2)),$((LINE_NUM+2))p" "$LOG_FILE")
        OPERATOR_ADDR=$(echo "$CONTEXT" | grep -o "operator_address 0x[a-fA-F0-9]\{40\}" | head -1 | cut -d' ' -f2)
        
        if [ -n "$OPERATOR_ADDR" ]; then
            echo "   🏷️  相关操作员地址: $OPERATOR_ADDR"
        fi
        
        # 提取交易详情
        TX_ID=$(echo "$line" | grep -o "tx [0-9]\+" | cut -d' ' -f2)
        NONCE=$(echo "$line" | grep -o "nonce [0-9]\+" | cut -d' ' -f2)
        GAS_LIMIT=$(echo "$line" | grep -o "gas_limit [0-9]\+" | cut -d' ' -f2)
        
        if [ -n "$TX_ID" ]; then echo "   📄 交易 ID: $TX_ID"; fi
        if [ -n "$NONCE" ]; then echo "   🔢 Nonce: $NONCE"; fi
        if [ -n "$GAS_LIMIT" ]; then echo "   ⛽ Gas Limit: $GAS_LIMIT"; fi
        echo ""
    done
else
    echo "✅ 未发现资金不足错误"
fi

# 提取 BSC 网络相关信息
echo ""
echo "🌐 BSC 网络信息:"
echo "==============="

BSC_LOGS=$(grep -n "BSC\|Chain ID.*97" "$LOG_FILE" | head -5)

if [ -n "$BSC_LOGS" ]; then
    echo "$BSC_LOGS"
else
    echo "❌ 未找到 BSC 网络相关日志"
fi

echo ""
echo "📋 总结和建议:"
echo "=============="
echo "1. 检查上述操作员地址的余额是否充足"
echo "2. 如果余额不足，请访问 BSC Testnet 水龙头充值"
echo "3. 建议每个操作员地址保持至少 0.1 BNB 余额"
echo "4. 水龙头地址: https://testnet.binance.org/faucet-smart"

echo ""
echo "🔧 快速充值命令:"
echo "================"
if [ -n "$OPERATOR_ADDRESSES" ]; then
    echo "$OPERATOR_ADDRESSES" | while read -r line; do
        ADDRESS=$(echo "$line" | cut -d' ' -f2)
        echo "# 为地址 $ADDRESS 申请测试 BNB"
        echo "# 访问: https://testnet.binance.org/faucet-smart"
        echo "# 输入地址: $ADDRESS"
        echo ""
    done
fi