#!/bin/bash

# 在外部节点服务器上部署 Nginx 反向代理

set -e

EXTERNAL_NODE_IP="13.228.79.240"
EXTERNAL_NODE_SSH_KEY="$HOME/zk_node1.pem"
MAIN_NODE_IP="54.255.184.251"

echo "=== 部署 Nginx 反向代理到外部节点 ==="
echo ""
echo "外部节点: $EXTERNAL_NODE_IP"
echo "主节点: $MAIN_NODE_IP"
echo ""

# 在外部节点服务器上安装和配置 Nginx
ssh -i $EXTERNAL_NODE_SSH_KEY ubuntu@$EXTERNAL_NODE_IP << 'ENDSSH'

# 安装 Nginx
echo "📦 安装 Nginx..."
sudo apt-get update
sudo apt-get install -y nginx

# 创建 Nginx 配置
echo "⚙️  配置 Nginx..."
sudo tee /etc/nginx/sites-available/tmai-proxy > /dev/null << 'EOF'
# tMai RPC 反向代理配置

upstream tmai_main_node {
    server 54.255.184.251:3050;
    keepalive 32;
}

# HTTP RPC (端口 4050)
server {
    listen 4050;
    server_name _;

    # 日志
    access_log /var/log/nginx/tmai-rpc-access.log;
    error_log /var/log/nginx/tmai-rpc-error.log;

    # 超时设置
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    location / {
        proxy_pass http://tmai_main_node;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 缓存设置（可选）
        # proxy_cache_bypass $http_upgrade;
    }

    # 健康检查端点
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}

# WebSocket RPC (端口 4051)
server {
    listen 4051;
    server_name _;

    access_log /var/log/nginx/tmai-ws-access.log;
    error_log /var/log/nginx/tmai-ws-error.log;

    location / {
        proxy_pass http://tmai_main_node;
        proxy_http_version 1.1;
        
        # WebSocket 必需
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # WebSocket 超时
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
EOF

# 启用配置
sudo ln -sf /etc/nginx/sites-available/tmai-proxy /etc/nginx/sites-enabled/

# 测试配置
echo "🔍 测试 Nginx 配置..."
sudo nginx -t

# 重启 Nginx
echo "🔄 重启 Nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "✅ Nginx 反向代理部署完成！"

ENDSSH

echo ""
echo "========================================="
echo "  ✅ 部署完成！"
echo "========================================="
echo ""
echo "服务信息:"
echo "  HTTP RPC: http://$EXTERNAL_NODE_IP:4050"
echo "  WS RPC:   ws://$EXTERNAL_NODE_IP:4051"
echo "  Health:   http://$EXTERNAL_NODE_IP:4050/health"
echo ""
echo "验证部署:"
echo "  curl -X POST http://$EXTERNAL_NODE_IP:4050 \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}'"
echo ""
echo "查看日志:"
echo "  ssh -i $EXTERNAL_NODE_SSH_KEY ubuntu@$EXTERNAL_NODE_IP"
echo "  sudo tail -f /var/log/nginx/tmai-rpc-access.log"
echo ""
echo "管理命令:"
echo "  重启: sudo systemctl restart nginx"
echo "  停止: sudo systemctl stop nginx"
echo "  状态: sudo systemctl status nginx"
