# 🚀 ZKStack BSC 预编译部署指南

## 📋 概述

本指南提供了使用**预编译二进制文件**部署 ZKStack BSC 节点的完整方案，无需在服务器上进行编译，大大节省部署时间和服务器资源。

## ✨ 主要优势

- ⚡ **快速部署**: 无需服务器编译，几分钟内完成部署
- 💾 **节省资源**: 服务器无需安装 Rust 编译环境
- 🔒 **环境隔离**: Docker 容器化部署，避免依赖冲突
- 🛠 **易于管理**: 内置管理脚本和监控工具
- 🔧 **BSC 优化**: 包含所有 BSC 兼容性修复

## 📦 部署方案

### 方案1: Docker 快速部署 (推荐)

适用于开发、测试和小规模生产环境。

#### 前置要求
- Docker 20.10+
- Docker Compose 2.0+
- 本机已编译的二进制文件

#### 部署步骤

1. **本机编译二进制文件**
```bash
# 在开发机器上编译
cd zkstack_cli
cargo build --release

cd ../core
cargo build --release --bin zksync_server
```

2. **传输文件到服务器**
```bash
# 将整个项目目录传输到服务器
rsync -av --exclude target/debug zksync-era/ user@server:/opt/zksync-era/
```

3. **服务器上快速部署**
```bash
cd /opt/zksync-era
chmod +x quick_deploy_prebuilt.sh

# 一键部署
./quick_deploy_prebuilt.sh deploy
```

### 方案2: 系统服务部署

适用于大规模生产环境，直接在系统上运行。

#### 部署步骤

1. **创建部署包**
```bash
# 在本机创建部署包
./deploy_prebuilt_bsc.sh testnet package
```

2. **传输到服务器**
```bash
scp zksync-bsc-*.tar.gz user@server:/tmp/
```

3. **服务器安装**
```bash
# 在服务器上
cd /tmp
tar -xzf zksync-bsc-*.tar.gz
cd zksync-era
sudo ./install.sh
sudo ./scripts/deploy_prebuilt_bsc.sh testnet setup
```

## 🔧 配置说明

### 环境变量配置

编辑 `.env` 文件设置关键参数：

```bash
# 网络配置
L1_CHAIN_ID=97  # BSC Testnet (主网使用 56)
L1_RPC_URL=https://bsc-testnet-dataseed.bnbchain.org

# 钱包配置 (必须设置)
OPERATOR_PRIVATE_KEY=0x你的操作员私钥
GOVERNOR_PRIVATE_KEY=0x你的治理者私钥

# 数据库配置 (自动生成)
DB_PASSWORD=自动生成的安全密码
```

### 网络选择

| 网络 | Chain ID | RPC URL | 用途 |
|------|----------|---------|------|
| BSC Testnet | 97 | https://bsc-testnet-dataseed.bnbchain.org | 测试开发 |
| BSC Mainnet | 56 | https://bsc-dataseed.binance.org/ | 生产环境 |

## 🛠 管理命令

### Docker 方案管理

```bash
# 查看状态
./quick_deploy_prebuilt.sh status

# 查看日志
./quick_deploy_prebuilt.sh logs

# 重启服务
./quick_deploy_prebuilt.sh restart

# 停止服务
./quick_deploy_prebuilt.sh stop

# 备份数据
./quick_deploy_prebuilt.sh backup
```

### 系统服务管理

```bash
# 查看服务状态
sudo systemctl status zksync-server-testnet

# 查看日志
sudo journalctl -u zksync-server-testnet -f

# 重启服务
sudo systemctl restart zksync-server-testnet

# 健康检查
/opt/zksync-era/health_check.sh
```

## 📊 服务端点

部署完成后，以下端点将可用：

| 服务 | 端点 | 说明 |
|------|------|------|
| HTTP API | http://localhost/api | JSON-RPC API |
| WebSocket | ws://localhost/ws | WebSocket API |
| 健康检查 | http://localhost/health | 服务健康状态 |
| 指标监控 | http://localhost:3312/metrics | Prometheus 指标 |

## 🔍 验证部署

### 1. 健康检查
```bash
curl http://localhost/health
# 期望输出: {"status":"ok",...}
```

### 2. 获取链ID
```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost/api
# 期望输出: {"jsonrpc":"2.0","id":1,"result":"0x61"}  # BSC Testnet
```

### 3. 检查服务状态
```bash
# Docker 方案
docker-compose -f docker-compose.prebuilt.yml ps

# 系统服务方案
systemctl status zksync-server-testnet
```

## 🚨 故障排除

### 常见问题

1. **二进制文件不存在**
   ```
   错误: 缺少预编译文件
   解决: 在本机运行编译命令
   ```

2. **架构不兼容**
   ```
   错误: 二进制文件无法运行
   解决: 确保本机和服务器架构一致 (x86_64 或 aarch64)
   ```

3. **私钥未设置**
   ```
   错误: 请在 .env 文件中设置有效的 OPERATOR_PRIVATE_KEY
   解决: 编辑 .env 文件，设置真实的私钥
   ```

4. **端口冲突**
   ```
   错误: 端口 3050 已被占用
   解决: 修改 .env 文件中的端口配置
   ```

5. **数据库连接失败**
   ```
   错误: 无法连接到 PostgreSQL
   解决: 检查 Docker 服务状态，重启 postgres 容器
   ```

### 日志查看

```bash
# Docker 方案 - 查看所有服务日志
docker-compose -f docker-compose.prebuilt.yml logs -f

# Docker 方案 - 查看特定服务日志
docker-compose -f docker-compose.prebuilt.yml logs -f zksync-server

# 系统服务方案 - 查看服务日志
sudo journalctl -u zksync-server-testnet -f --since "1 hour ago"
```

### 性能监控

```bash
# 查看容器资源使用
docker stats

# 查看系统资源
htop

# 查看网络连接
netstat -tlnp | grep :3050
```

## 💰 资金要求

确保操作员地址有足够余额：

| 网络 | 代币 | 最低余额 | 获取方式 |
|------|------|----------|----------|
| BSC Testnet | tBNB | 0.1 tBNB | [BSC 测试网水龙头](https://testnet.bnbchain.org/faucet-smart) |
| BSC Mainnet | BNB | 0.5 BNB | 交易所购买 |

## 🔒 安全建议

1. **私钥安全**
   - 使用专用的操作员钱包
   - 定期轮换私钥
   - 不要在日志中暴露私钥

2. **网络安全**
   - 配置防火墙规则
   - 使用 HTTPS (生产环境)
   - 限制管理端口访问

3. **系统安全**
   - 定期更新系统
   - 监控异常活动
   - 设置日志告警

## 📈 扩展和优化

### 生产环境优化

1. **配置 HTTPS**
```bash
# 安装 SSL 证书
sudo certbot --nginx -d your-domain.com
```

2. **设置监控**
```bash
# 启用 Prometheus + Grafana
docker-compose -f docker-compose.prebuilt.yml -f monitoring.yml up -d
```

3. **配置负载均衡**
```bash
# 多实例部署
docker-compose -f docker-compose.prebuilt.yml up -d --scale zksync-server=3
```

### 性能调优

1. **数据库优化**
   - 调整 PostgreSQL 配置
   - 设置连接池
   - 启用查询缓存

2. **网络优化**
   - 使用 CDN
   - 启用 Gzip 压缩
   - 配置缓存策略

## 📞 支持和帮助

如果遇到问题：

1. 查看日志文件
2. 检查 [故障排除](#-故障排除) 部分
3. 运行健康检查脚本
4. 查看 GitHub Issues

---

**🎉 现在你可以快速部署 ZKStack BSC 节点，无需在服务器上编译！**