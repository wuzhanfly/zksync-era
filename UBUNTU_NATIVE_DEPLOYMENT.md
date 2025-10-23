# 🚀 ZKStack BSC Ubuntu 24.04 原生部署指南

## 📋 概述

本指南提供了在 Ubuntu 24.04 服务器上使用**预编译二进制文件**原生部署 ZKStack BSC 节点的完整方案。

## ✨ 部署优势

- ⚡ **极速部署**: 使用预编译文件，5-10分钟完成部署
- 🎯 **原生性能**: 直接在系统上运行，无容器开销
- 💾 **资源优化**: 针对 Ubuntu 24.04 优化的配置
- 🔧 **完整功能**: 包含所有 BSC 兼容性修复
- 🛡️ **生产就绪**: systemd 服务管理，自动重启

## 📦 部署文件

| 文件 | 用途 | 说明 |
|------|------|------|
| `pre_deploy_check.sh` | 部署前检查 | 验证系统环境和文件 |
| `ubuntu_quick_deploy.sh` | 快速部署 | 5分钟快速部署脚本 |
| `deploy_native_ubuntu.sh` | 完整部署 | 生产级完整部署脚本 |

## 🚀 快速开始

### 1. 部署前检查

```bash
# 检查系统环境
chmod +x pre_deploy_check.sh
./pre_deploy_check.sh
```

### 2. 快速部署 (推荐新手)

```bash
# 一键快速部署
chmod +x ubuntu_quick_deploy.sh
sudo ./ubuntu_quick_deploy.sh
```

### 3. 完整部署 (推荐生产)

```bash
# 完整功能部署
chmod +x deploy_native_ubuntu.sh
sudo ./deploy_native_ubuntu.sh testnet
```

## 📋 前置要求

### 系统要求

- **操作系统**: Ubuntu 24.04 LTS
- **架构**: x86_64 (amd64)
- **权限**: sudo 管理员权限

### 硬件要求

| 组件 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 2核 | 4核+ |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 50GB | 100GB+ |
| 网络 | 10Mbps | 100Mbps+ |

### 预编译文件

确保以下文件存在：
```
zkstack_cli/target/release/zkstack
core/target/release/zksync_server
```

如果没有，请先编译：
```bash
# 在开发机器上编译
cd zkstack_cli && cargo build --release
cd ../core && cargo build --release --bin zksync_server
```

## 🔧 部署步骤详解

### 步骤1: 环境检查

```bash
./pre_deploy_check.sh
```

检查项目：
- ✅ Ubuntu 24.04 系统
- ✅ 硬件资源充足
- ✅ 网络连接正常
- ✅ 预编译文件存在
- ✅ 端口未被占用

### 步骤2: 选择部署方式

#### 方式A: 快速部署 (5分钟)
```bash
sudo ./ubuntu_quick_deploy.sh
```

**特点:**
- 最简化配置
- 自动安装依赖
- 仅部署 BSC Testnet
- 适合测试和开发

#### 方式B: 完整部署 (10分钟)
```bash
# BSC Testnet
sudo ./deploy_native_ubuntu.sh testnet

# BSC Mainnet
sudo ./deploy_native_ubuntu.sh mainnet
```

**特点:**
- 完整生产配置
- 详细日志和监控
- 支持主网和测试网
- 包含安全配置

### 步骤3: 验证部署

```bash
# 检查服务状态
systemctl status zksync-bsc

# 检查 API 响应
curl http://localhost/health

# 测试链ID
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost/api
```

## 📊 部署后配置

### 服务管理

```bash
# 查看状态
sudo systemctl status zksync-bsc

# 启动服务
sudo systemctl start zksync-bsc

# 停止服务
sudo systemctl stop zksync-bsc

# 重启服务
sudo systemctl restart zksync-bsc

# 查看日志
sudo journalctl -u zksync-bsc -f
```

### 配置文件位置

| 配置类型 | 文件路径 |
|----------|----------|
| 主配置 | `/opt/zksync/.env` |
| 服务配置 | `/etc/systemd/system/zksync-bsc.service` |
| Nginx配置 | `/etc/nginx/sites-available/zksync-bsc` |
| 数据库密码 | `/etc/zksync/db_password` |

### 重要目录

| 目录 | 用途 |
|------|------|
| `/opt/zksync` | 主程序目录 |
| `/var/lib/zksync` | 数据存储目录 |
| `/var/log/zksync` | 日志目录 |

## 🔗 服务端点

部署完成后可访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| HTTP API | `http://localhost/api` | JSON-RPC API |
| WebSocket | `ws://localhost/ws` | WebSocket API |
| 健康检查 | `http://localhost/health` | 服务状态 |
| 服务信息 | `http://localhost/` | 基本信息 |

## 🛠 管理工具

### 快速部署管理脚本

```bash
# 状态检查
/opt/zksync/status.sh

# 查看日志
journalctl -u zksync-bsc -f
```

### 完整部署管理脚本

```bash
# 健康检查
/opt/zksync/scripts/health_check.sh

# 数据备份
/opt/zksync/scripts/backup.sh

# 系统监控
/opt/zksync/scripts/monitor.sh

# 服务更新
sudo /opt/zksync/scripts/update.sh
```

## 🔒 安全配置

### 防火墙设置

```bash
# 基本防火墙规则 (自动配置)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### SSL 证书 (生产环境)

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d your-domain.com
```

### 数据库安全

- 数据库密码自动生成并安全存储
- 仅本地连接，不对外开放
- 定期备份数据

## 💰 资金准备

确保操作员地址有足够余额：

### BSC Testnet
- **代币**: tBNB
- **最低余额**: 0.1 tBNB
- **获取方式**: [BSC 测试网水龙头](https://testnet.bnbchain.org/faucet-smart)

### BSC Mainnet
- **代币**: BNB
- **最低余额**: 0.5 BNB
- **获取方式**: 交易所购买

## 🚨 故障排除

### 常见问题

1. **服务启动失败**
   ```bash
   # 查看详细日志
   sudo journalctl -u zksync-bsc -n 50
   
   # 检查配置文件
   cat /opt/zksync/.env
   ```

2. **API 无响应**
   ```bash
   # 检查端口监听
   netstat -tlnp | grep :3050
   
   # 检查 Nginx 状态
   sudo systemctl status nginx
   ```

3. **数据库连接失败**
   ```bash
   # 检查 PostgreSQL 状态
   sudo systemctl status postgresql
   
   # 测试数据库连接
   sudo -u postgres psql -c "\l"
   ```

4. **权限问题**
   ```bash
   # 修复文件权限
   sudo chown -R zksync:zksync /opt/zksync
   sudo chown -R zksync:zksync /var/lib/zksync
   ```

### 日志分析

```bash
# 查看实时日志
sudo journalctl -u zksync-bsc -f

# 查看错误日志
sudo journalctl -u zksync-bsc -p err

# 查看最近1小时日志
sudo journalctl -u zksync-bsc --since "1 hour ago"
```

### 性能监控

```bash
# 系统资源使用
htop

# 磁盘使用
df -h

# 网络连接
netstat -tlnp

# 进程状态
ps aux | grep zksync
```

## 📈 性能优化

### 数据库优化

```sql
-- 连接到数据库
sudo -u postgres psql zk_bsc_testnet

-- 查看连接数
SELECT count(*) FROM pg_stat_activity;

-- 查看数据库大小
SELECT pg_size_pretty(pg_database_size('zk_bsc_testnet'));
```

### 系统优化

```bash
# 增加文件描述符限制
echo "zksync soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "zksync hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化网络参数
echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 🔄 更新和维护

### 更新二进制文件

```bash
# 1. 停止服务
sudo systemctl stop zksync-bsc

# 2. 备份数据
/opt/zksync/scripts/backup.sh

# 3. 替换二进制文件
sudo cp new_zkstack /opt/zksync/bin/zkstack
sudo cp new_zksync_server /opt/zksync/bin/zksync_server
sudo chmod +x /opt/zksync/bin/*

# 4. 启动服务
sudo systemctl start zksync-bsc

# 5. 验证更新
/opt/zksync/scripts/health_check.sh
```

### 定期维护

```bash
# 每日备份 (添加到 crontab)
0 2 * * * /opt/zksync/scripts/backup.sh

# 每周日志清理
0 3 * * 0 journalctl --vacuum-time=7d

# 每月系统更新
sudo apt update && sudo apt upgrade -y
```

## 📞 支持和帮助

### 获取帮助

1. **查看脚本帮助**
   ```bash
   ./pre_deploy_check.sh --help
   ./ubuntu_quick_deploy.sh --help
   ./deploy_native_ubuntu.sh --help
   ```

2. **检查系统状态**
   ```bash
   /opt/zksync/status.sh
   /opt/zksync/scripts/health_check.sh
   ```

3. **查看日志**
   ```bash
   sudo journalctl -u zksync-bsc -f
   ```

### 社区资源

- [ZKSync 官方文档](https://docs.zksync.io/)
- [BSC 开发者文档](https://docs.bnbchain.org/)
- [GitHub Issues](https://github.com/matter-labs/zksync-era/issues)

---

## 🎉 总结

通过本指南，你可以在 Ubuntu 24.04 服务器上快速部署一个完全功能的 ZKStack BSC 节点：

✅ **5分钟快速部署** - 适合测试和开发  
✅ **生产级配置** - 适合正式环境  
✅ **完整监控** - 健康检查和日志管理  
✅ **安全配置** - 防火墙和权限控制  
✅ **BSC 优化** - 包含所有兼容性修复  

现在你可以开始在 BSC 网络上构建和部署你的 ZK 应用了！🚀