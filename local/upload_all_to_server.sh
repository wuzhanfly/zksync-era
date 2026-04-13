#!/bin/bash

set -e

SERVER="ubuntu@54.255.184.251"
KEY="/home/jerry/zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"

echo "=== 上传所有文件到服务器 ==="
echo ""

# 检查 SSH 密钥
if [ ! -f "$KEY" ]; then
    echo "❌ SSH 密钥不存在: $KEY"
    exit 1
fi

chmod 600 $KEY

# 检查 tmai_ecosystem
if [ ! -d "tmai_ecosystem" ]; then
    echo "❌ tmai_ecosystem 不存在"
    echo "请先运行: ./local/deploy_contracts.sh"
    exit 1
fi

echo "1️⃣ 上传 docker-compose 文件..."
scp -i $KEY server/docker-compose.yml $SERVER:$REMOTE_PATH/
echo "✅ docker-compose.yml 已上传"

echo ""
echo "2️⃣ 上传启动脚本..."
scp -i $KEY server/start_server.sh $SERVER:$REMOTE_PATH/
ssh -i $KEY $SERVER "chmod +x $REMOTE_PATH/start_server.sh"
echo "✅ start_server.sh 已上传"

echo ""
echo "3️⃣ 打包 tmai_ecosystem..."
tar czf tmai_ecosystem.tar.gz tmai_ecosystem/
echo "✅ 打包完成"

echo ""
echo "4️⃣ 上传 tmai_ecosystem (这可能需要几分钟)..."
scp -i $KEY tmai_ecosystem.tar.gz $SERVER:$REMOTE_PATH/
echo "✅ 上传完成"

echo ""
echo "5️⃣ 在服务器上解压..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
tar xzf tmai_ecosystem.tar.gz
rm tmai_ecosystem.tar.gz
echo "✅ 解压完成"
ls -la tmai_ecosystem/
EOF

# 清理本地临时文件
rm tmai_ecosystem.tar.gz

echo ""
echo "========================================="
echo "  ✅ 所有文件已上传到服务器！"
echo "========================================="
echo ""
echo "服务器文件结构:"
echo "  /home/ubuntu/node/"
echo "  ├── docker-compose.yml"
echo "  ├── docker-compose.postgres.yml"
echo "  ├── start_server.sh"
echo "  └── tmai_ecosystem/"
echo ""
echo "下一步 - 启动服务器:"
echo "  ssh -i $KEY $SERVER"
echo "  cd $REMOTE_PATH"
echo "  ./start_server.sh"
echo ""
echo "或者远程启动:"
echo "  ssh -i $KEY $SERVER 'cd $REMOTE_PATH && ./start_server.sh'"
echo ""

