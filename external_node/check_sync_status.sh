#!/bin/bash

# 检查外部节点同步状态

MAIN_NODE_IP="54.255.184.251"
EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_RPC_PORT="4050"
EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"

echo "=== 检查节点同步状态 ==="
echo ""

# 获取主节点区块高度
echo "📊 主节点 ($MAIN_NODE_IP):"
MAIN_BLOCK=$(curl -s -X POST http://$MAIN_NODE_IP:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result')

if [ "$MAIN_BLOCK" != "null" ] && [ -n "$MAIN_BLOCK" ]; then
    MAIN_BLOCK_DEC=$((16#${MAIN_BLOCK#0x}))
    echo "  区块高度: $MAIN_BLOCK_DEC ($MAIN_BLOCK)"
else
    echo "  ❌ 无法获取区块高度"
    exit 1
fi

echo ""

# 获取外部节点区块高度
echo "📊 外部节点 ($EXTERNAL_NODE_IP:$EXTERNAL_NODE_RPC_PORT):"
EXTERNAL_BLOCK=$(curl -s -X POST http://$EXTERNAL_NODE_IP:$EXTERNAL_NODE_RPC_PORT \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq -r '.result')

if [ "$EXTERNAL_BLOCK" != "null" ] && [ -n "$EXTERNAL_BLOCK" ]; then
    EXTERNAL_BLOCK_DEC=$((16#${EXTERNAL_BLOCK#0x}))
    echo "  区块高度: $EXTERNAL_BLOCK_DEC ($EXTERNAL_BLOCK)"
    
    # 计算差距
    DIFF=$((MAIN_BLOCK_DEC - EXTERNAL_BLOCK_DEC))
    echo "  差距: $DIFF 个区块"
    
    if [ $DIFF -eq 0 ]; then
        echo "  ✅ 已完全同步"
    elif [ $DIFF -lt 10 ]; then
        echo "  ⚠️  接近同步 (差距 < 10 区块)"
    else
        echo "  ⏳ 正在同步中..."
    fi
    
    # 计算同步进度
    if [ $MAIN_BLOCK_DEC -gt 0 ]; then
        PROGRESS=$((EXTERNAL_BLOCK_DEC * 100 / MAIN_BLOCK_DEC))
        echo "  进度: $PROGRESS%"
    fi
else
    echo "  ❌ 无法获取区块高度（可能还在启动中）"
fi

echo ""
echo "========================================="
echo ""
echo "查看外部节点日志:"
echo "  ssh -i $EXTERNAL_NODE_SSH_KEY ubuntu@$EXTERNAL_NODE_IP"
echo "  docker logs -f tmai-external-node"

