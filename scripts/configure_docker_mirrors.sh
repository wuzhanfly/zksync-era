#!/bin/bash

# 配置国内 Docker 镜像源脚本

echo "🔧 配置国内 Docker 镜像源..."

# 创建 Docker 配置目录
sudo mkdir -p /etc/docker

# 创建 daemon.json 配置文件
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://ccr.ccs.tencentyun.com"
  ]
}
EOF

echo "✅ Docker 镜像源配置完成"

# 重启 Docker 服务
echo "🔄 重启 Docker 服务..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "✅ Docker 服务重启完成"

# 验证配置
echo "🔍 验证 Docker 镜像源配置..."
docker info | grep -A 10 "Registry Mirrors"

echo ""
echo "🎉 配置完成！现在可以尝试拉取镜像了"