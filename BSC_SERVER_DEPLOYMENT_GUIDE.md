# 🚀 ZKStack BSC 服务器部署指南

## 📋 **部署概述**

本指南将帮助你在生产服务器上部署支持BSC网络的ZKStack节点。

## 🛠 **服务器要求**

### 硬件要求
- **CPU**: 8核以上 (推荐16核)
- **内存**: 32GB以上 (推荐64GB)
- **存储**: 1TB SSD以上
- **网络**: 稳定的互联网连接，带宽100Mbps+

### 软件要求
- **操作系统**: Ubuntu 20.04+ / CentOS 8+
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **PostgreSQL**: 14+
- **Rust**: 1.75+
- **Node.js**: 18+

## 🔧 **部署步骤**

### 1. 环境准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要工具
sudo apt install -y git curl wget build-essential pkg-config libssl-dev

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 安装Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 安装Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 2. 克隆和编译ZKStack

```bash
# 克隆仓库
git clone https://github.com/matter-labs/zksync-era.git
cd zksync-era

# 应用BSC兼容性修复 (如果还没有应用)
# 这些修复已经在开发环境中完成，需要确保生产环境也有相同的修复

# 编译zkstack CLI
cd zkstack_cli
cargo build --release

# 编译核心组件
cd ../core
cargo build --release --bin zksync_server
```

### 3. 数据库设置

```bash
# 启动PostgreSQL (使用Docker)
docker run -d \
  --name zksync-postgres \
  -e POSTGRES_DB=zksync \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:14

# 等待数据库启动
sleep 10

# 创建BSC专用数据库
docker exec -it zksync-postgres psql -U postgres -c "CREATE DATABASE zk_bsc_mainnet;"
docker exec -it zksync-postgres psql -U postgres -c "CREATE DATABASE zk_bsc_testnet;"
```

### 4. 配置环境变量

```bash
# 创建环境配置文件
cat > .env.bsc << 'EOF'
# BSC网络配置
L1_CHAIN_ID=56  # BSC Mainnet (测试网使用97)
L1_RPC_URL=https://bsc-dataseed.binance.org/  # BSC Mainnet RPC

# 数据库配置
DATABASE_URL=postgres://postgres:your_secure_password@localhost:5432/zk_bsc_mainnet

# 钱包配置 (请使用你自己的私钥)
OPERATOR_PRIVATE_KEY=your_operator_private_key
GOVERNOR_PRIVATE_KEY=your_governor_private_key

# 服务配置
API_WEB3_JSON_RPC_HTTP_PORT=3050
API_WEB3_JSON_RPC_WS_PORT=3051
API_PROMETHEUS_PORT=3312
API_HEALTHCHECK_PORT=3081

# 日志配置
RUST_LOG=info
RUST_BACKTRACE=1
EOF

# 加载环境变量
source .env.bsc
```

### 5. 初始化生态系统

```bash
# 设置BSC环境变量
export L1_CHAIN_ID=56  # 或 97 用于测试网
export L1_RPC_URL="https://bsc-dataseed.binance.org/"

# 运行生态系统初始化
./zkstack_cli/target/release/zkstack ecosystem init \
    --l1-rpc-url "$L1_RPC_URL" \
    --server-db-url "postgres://postgres:your_secure_password@localhost:5432" \
    --server-db-name "zk_bsc_mainnet" \
    --deploy-ecosystem true \
    --deploy-erc20 true \
    --deploy-paymaster true \
    --timeout 1200 \
    --retries 10 \
    --observability true
```

### 6. 创建系统服务

```bash
# 创建systemd服务文件
sudo tee /etc/systemd/system/zksync-server.service > /dev/null << 'EOF'
[Unit]
Description=ZKSync Server for BSC
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=zksync
Group=zksync
WorkingDirectory=/opt/zksync-era
Environment=L1_CHAIN_ID=56
Environment=L1_RPC_URL=https://bsc-dataseed.binance.org/
EnvironmentFile=/opt/zksync-era/.env.bsc
ExecStart=/opt/zksync-era/core/target/release/zksync_server \
    --genesis-path /opt/zksync-era/chains/bsc_chain/configs/genesis.yaml \
    --config-path /opt/zksync-era/chains/bsc_chain/configs/general.yaml \
    --wallets-path /opt/zksync-era/chains/bsc_chain/configs/wallets.yaml \
    --secrets-path /opt/zksync-era/chains/bsc_chain/configs/secrets.yaml \
    --contracts-config-path /opt/zksync-era/chains/bsc_chain/configs/contracts.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=zksync-server

[Install]
WantedBy=multi-user.target
EOF

# 创建zksync用户
sudo useradd -r -s /bin/false zksync

# 移动文件到生产目录
sudo mkdir -p /opt/zksync-era
sudo cp -r . /opt/zksync-era/
sudo chown -R zksync:zksync /opt/zksync-era

# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable zksync-server
sudo systemctl start zksync-server
```

### 7. 配置反向代理 (Nginx)

```bash
# 安装Nginx
sudo apt install -y nginx

# 创建Nginx配置
sudo tee /etc/nginx/sites-available/zksync-bsc > /dev/null << 'EOF'
server {
    listen 80;
    server_name your-domain.com;  # 替换为你的域名

    # JSON-RPC HTTP API
    location /api {
        proxy_pass http://localhost:3050;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket API
    location /ws {
        proxy_pass http://localhost:3051;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 健康检查
    location /health {
        proxy_pass http://localhost:3081/health;
    }

    # Prometheus指标
    location /metrics {
        proxy_pass http://localhost:3312/metrics;
        allow 127.0.0.1;  # 只允许本地访问
        deny all;
    }
}
EOF

# 启用站点
sudo ln -s /etc/nginx/sites-available/zksync-bsc /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 8. 配置SSL证书 (Let's Encrypt)

```bash
# 安装Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取SSL证书
sudo certbot --nginx -d your-domain.com

# 设置自动续期
sudo crontab -e
# 添加以下行:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

### 9. 监控和日志

```bash
# 查看服务状态
sudo systemctl status zksync-server

# 查看实时日志
sudo journalctl -u zksync-server -f

# 查看错误日志
sudo journalctl -u zksync-server --since "1 hour ago" -p err

# 设置日志轮转
sudo tee /etc/logrotate.d/zksync > /dev/null << 'EOF'
/var/log/zksync/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 zksync zksync
    postrotate
        systemctl reload zksync-server
    endscript
}
EOF
```

## 🔒 **安全配置**

### 防火墙设置
```bash
# 配置UFW防火墙
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow from 127.0.0.1 to any port 3312  # Prometheus
sudo ufw allow from your_monitoring_ip to any port 3312
```

### 私钥安全
```bash
# 创建安全的私钥文件
sudo mkdir -p /etc/zksync/secrets
sudo chmod 700 /etc/zksync/secrets

# 将私钥存储在安全位置
echo "your_operator_private_key" | sudo tee /etc/zksync/secrets/operator.key
echo "your_governor_private_key" | sudo tee /etc/zksync/secrets/governor.key
sudo chmod 600 /etc/zksync/secrets/*.key
sudo chown zksync:zksync /etc/zksync/secrets/*.key
```

## 📊 **监控和维护**

### 健康检查脚本
```bash
#!/bin/bash
# 创建健康检查脚本
cat > /opt/zksync-era/health_check.sh << 'EOF'
#!/bin/bash

# 检查服务状态
if ! systemctl is-active --quiet zksync-server; then
    echo "ERROR: ZKSync server is not running"
    exit 1
fi

# 检查API响应
if ! curl -s http://localhost:3050/health > /dev/null; then
    echo "ERROR: API not responding"
    exit 1
fi

# 检查数据库连接
if ! pg_isready -h localhost -p 5432 -U postgres > /dev/null; then
    echo "ERROR: Database not accessible"
    exit 1
fi

echo "OK: All services healthy"
EOF

chmod +x /opt/zksync-era/health_check.sh

# 设置定期健康检查
echo "*/5 * * * * /opt/zksync-era/health_check.sh" | sudo crontab -u zksync -
```

## 🚀 **启动和验证**

```bash
# 启动所有服务
sudo systemctl start postgresql
sudo systemctl start zksync-server
sudo systemctl start nginx

# 验证部署
curl http://localhost:3050/health
curl http://your-domain.com/health

# 检查BSC网络连接
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:3050/api
```

## 📝 **维护命令**

```bash
# 重启服务
sudo systemctl restart zksync-server

# 更新代码
cd /opt/zksync-era
sudo -u zksync git pull
sudo -u zksync cargo build --release
sudo systemctl restart zksync-server

# 备份数据库
pg_dump -h localhost -U postgres zk_bsc_mainnet > backup_$(date +%Y%m%d).sql

# 查看性能指标
curl http://localhost:3312/metrics
```

## ⚠️ **注意事项**

1. **私钥安全**: 确保私钥文件权限正确，只有zksync用户可以读取
2. **防火墙**: 只开放必要的端口，限制管理端口的访问
3. **监控**: 设置适当的监控和告警
4. **备份**: 定期备份数据库和配置文件
5. **更新**: 定期更新系统和依赖项

## 🆘 **故障排除**

### 常见问题
1. **服务无法启动**: 检查日志 `sudo journalctl -u zksync-server -f`
2. **数据库连接失败**: 验证PostgreSQL服务和连接字符串
3. **BSC网络问题**: 检查RPC URL和网络连接
4. **内存不足**: 增加服务器内存或优化配置

### 联系支持
如果遇到问题，请检查:
- 系统日志: `/var/log/syslog`
- 应用日志: `sudo journalctl -u zksync-server`
- 网络连接: `curl -I https://bsc-dataseed.binance.org/`

---

**部署完成后，你的ZKStack节点将在BSC网络上运行，支持所有BSC特有的功能和优化！** 🎉