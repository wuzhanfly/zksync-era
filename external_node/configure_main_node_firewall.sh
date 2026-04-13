#!/bin/bash

# 配置主节点防火墙，允许外部节点访问

MAIN_NODE_SSH_KEY="$HOME/zk_gas.pem"
MAIN_NODE_IP="54.255.184.251"
EXTERNAL_NODE_IP="13.228.79.240"

echo "=== 配置主节点防火墙 ==="
echo ""

ssh -i $MAIN_NODE_SSH_KEY ubuntu@$MAIN_NODE_IP << ENDSSH
echo "1️⃣ 检查当前防火墙状态..."
sudo ufw status

echo ""
echo "2️⃣ 允许外部节点访问 RPC 端口..."
sudo ufw allow from $EXTERNAL_NODE_IP to any port 3050 proto tcp

echo ""
echo "3️⃣ 确保主节点监听所有接口..."
cd /home/ubuntu/node

# 检查 docker-compose.yml 中的端口配置
if grep -q "127.0.0.1:3050" docker-compose.yml; then
    echo "⚠️  检测到主节点只监听 127.0.0.1"
    echo "   需要修改为 0.0.0.0:3050"
    echo ""
    echo "   请手动修改 docker-compose.yml:"
    echo "   将 '127.0.0.1:3050:3050' 改为 '0.0.0.0:3050:3050'"
    echo "   然后重启: docker compose restart tmai-server"
else
    echo "✅ 端口配置正确"
fi

echo ""
echo "4️⃣ 测试端口是否开放..."
sudo netstat -tlnp | grep :3050 || echo "端口 3050 未监听"

echo ""
echo "✅ 防火墙配置完成"
ENDSSH

echo ""
echo "========================================="
echo "  配置完成"
echo "========================================="
echo ""
echo "从外部节点测试连接:"
echo "  ssh -i zk_node1.pem ubuntu@$EXTERNAL_NODE_IP"
echo "  curl -X POST http://$MAIN_NODE_IP:3050 \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"

