#!/bin/bash

set -e

SERVER="ubuntu@54.255.184.251"
KEY="zk_gas.pem"
REMOTE_PATH="/home/ubuntu/node"

echo "=== 部署所有文件到服务器 ==="
echo ""

# 检查 SSH 密钥
if [ ! -f "$KEY" ]; then
    echo "❌ SSH 密钥不存在: $KEY"
    exit 1
fi

chmod 600 $KEY

# 检查 tmai_ecosystem
if [ ! -d "tmai_ecosystem" ]; then
    echo "❌ tmai_ecosystem 目录不存在"
    exit 1
fi

echo "1️⃣ 上传 docker-compose.yml..."
scp -i $KEY server/docker-compose.yml $SERVER:$REMOTE_PATH/

echo ""
echo "2️⃣ 上传启动脚本..."
scp -i $KEY server/start_server.sh $SERVER:$REMOTE_PATH/
ssh -i $KEY $SERVER "chmod +x $REMOTE_PATH/start_server.sh"

echo ""
echo "3️⃣ 打包并上传 tmai_ecosystem..."
tar czf tmai_ecosystem.tar.gz tmai_ecosystem/
scp -i $KEY tmai_ecosystem.tar.gz $SERVER:$REMOTE_PATH/

echo ""
echo "4️⃣ 在服务器上解压..."
ssh -i $KEY $SERVER << 'EOF'
cd /home/ubuntu/node
tar xzf tmai_ecosystem.tar.gz
rm tmai_ecosystem.tar.gz
echo "✅ 文件已解压"
EOF

# 清理本地临时文件
rm tmai_ecosystem.tar.gz

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "服务器文件结构:"
echo "  /home/ubuntu/node/"
echo "  ├── docker-compose.yml"
echo "  ├── start_server.sh"
echo "  ├── tmai_ecosystem/"
echo "  └── tmai-server.tar.gz (Docker 镜像)"
echo ""
echo "下一步:"
echo "  1. SSH 到服务器: ssh -i $KEY $SERVER"
echo "  2. 进入目录: cd $REMOTE_PATH"
echo "  3. 启动服务: ./start_server.sh"
echo ""

