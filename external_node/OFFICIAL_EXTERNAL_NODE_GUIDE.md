# 官方 External Node 部署指南

## 📋 概述

根据 [ZKsync 官方文档](https://matter-labs.github.io/zksync-era/core/latest/guides/external-node/01_intro.html),External Node 是主节点的**只读副本**,通过以下方式工作:

1. 从主节点获取区块数据
2. 本地重新执行交易
3. 提供 Web3 API 服务

## 🔍 关键发现

### External Node 二进制文件

官方使用 `zksync_external_node` 二进制文件,而不是 `zksync_server` + `--external-node` 参数。

**证据**:
- Dockerfile: `docker/external-node/Dockerfile`
- 编译命令: `cargo build --bin zksync_external_node`
- 启动命令: `exec zksync_external_node "$@"`

### 与主节点的区别

| 特性 | 主节点 (zksync_server) | External Node (zksync_external_node) |
|------|----------------------|-----------------------------------|
| 二进制文件 | `zksync_server` | `zksync_external_node` |
| 功能 | 处理交易、生成区块 | 只读副本、同步数据 |
| 数据源 | L1 + 本地 | 主节点 API |
| 写入权限 | ✅ 可写 | ❌ 只读 |

## 🏗️ 构建 External Node 镜像

### 方法 1: 使用官方 Dockerfile

```bash
# 在项目根目录执行
bash external_node/build_external_node.sh
```

这会使用 `docker/external-node/Dockerfile` 构建镜像,包含:
- `zksync_external_node` 二进制文件
- `block_reverter` 工具
- 系统合约
- 数据库迁移文件

**构建时间**: 20-30 分钟

### 方法 2: 使用官方预构建镜像

```bash
# 拉取官方镜像
docker pull matterlabs/external-node:2.0-v28.0.0

# 或使用最新版本
docker pull matterlabs/external-node:latest
```

## 📝 配置 External Node

### 必需的环境变量

```bash
# 数据库配置
DATABASE_URL=postgres://postgres:password@postgres:5432/zksync_external_node
DATABASE_POOL_SIZE=50

# L1 配置
EN_ETH_CLIENT_URL=http://13.212.114.138:10575  # BSC Testnet RPC
EN_L1_CHAIN_ID=97                               # BSC Testnet
EN_L2_CHAIN_ID=9720                             # tMai Chain ID

# 主节点 URL
EN_MAIN_NODE_URL=http://54.255.184.251:3050

# RocksDB 路径
EN_STATE_CACHE_PATH=/db/state_cache
EN_MERKLE_TREE_PATH=/db/merkle_tree

# API 配置
EN_HTTP_PORT=3060
EN_WS_PORT=3061
EN_HEALTHCHECK_PORT=3081

# API 命名空间
EN_API_NAMESPACES=eth,net,web3,zks,pubsub,en

# 日志
RUST_LOG=info,zksync_core=info,zksync_dal=info
```

### 可选配置

```bash
# 快照恢复（推荐）
EN_SNAPSHOTS_RECOVERY_ENABLED=true

# 数据修剪
EN_PRUNING_ENABLED=false

# 内存优化
EN_MERKLE_TREE_BLOCK_CACHE_SIZE_MB=4096
EN_MERKLE_TREE_INCLUDE_INDICES_AND_FILTERS_IN_BLOCK_CACHE=true
```

## 🚀 部署步骤

### 步骤 1: 构建镜像

```bash
bash external_node/build_external_node.sh
```

### 步骤 2: 部署到服务器

```bash
bash external_node/deploy_official_external_node.sh
```

这个脚本会:
1. ✅ 检查镜像是否存在
2. ✅ 测试主节点连接
3. ✅ 导出并上传镜像
4. ✅ 创建配置文件
5. ✅ 启动服务

### 步骤 3: 验证部署

```bash
# 检查 Chain ID
curl -X POST http://13.228.79.240:4050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# 应该返回: {"jsonrpc":"2.0","result":"0x25f8","id":1}
```

## 📊 Docker Compose 配置

```yaml
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: notsecurepassword
      POSTGRES_DB: zksync_external_node
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    command: postgres -c max_connections=200

  external-node:
    image: tmai-external-node:latest
    depends_on:
      - postgres
    env_file:
      - .env
    ports:
      - "4050:3060"  # HTTP RPC
      - "4051:3061"  # WebSocket
      - "4071:3081"  # Health check
    volumes:
      - ./db:/db
    restart: unless-stopped
```

## 🔧 启动命令

External Node 的 entrypoint 非常简单:

```bash
#!/bin/bash
set -e

# 准备数据库
sqlx database setup

# 运行 External Node
exec zksync_external_node "$@"
```

**不需要任何额外参数**,所有配置通过环境变量传递。

## 📈 同步过程

### 初始化模式

External Node 支持 3 种初始化模式:

1. **从快照恢复** (推荐)
   - 最快的方式
   - 只有快照之后的数据
   - 设置: `EN_SNAPSHOTS_RECOVERY_ENABLED=true`

2. **从数据库转储恢复**
   - 完整的历史数据
   - 需要下载大型数据库文件
   - 适合归档节点

3. **从创世区块同步**
   - 不推荐
   - 可能需要数月时间
   - 仅用于测试

### 同步时间估算

- **快照恢复**: 1-10 小时
- **数据库转储**: 几小时到一天
- **创世同步**: 数月（不推荐）

## 🔍 监控和调试

### 查看日志

```bash
ssh -i ~/zk_node1.pem ubuntu@13.228.79.240
docker logs -f tmai-external-node
```

### 检查同步状态

```bash
bash external_node/check_sync_status.sh
```

### 健康检查

```bash
curl http://13.228.79.240:4071/health
```

## ⚠️ 常见问题

### 问题 1: 无法连接主节点

**症状**: `failed to connect to main node`

**解决方案**:
```bash
# 测试主节点连接
curl -X POST http://54.255.184.251:3050 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# 检查防火墙
# 确保主节点监听 0.0.0.0 而不是 127.0.0.1
```

### 问题 2: 数据库连接失败

**症状**: `database connection failed`

**解决方案**:
```bash
# 检查 PostgreSQL 状态
docker ps | grep postgres

# 重启 PostgreSQL
docker compose restart postgres
```

### 问题 3: RocksDB 错误

**症状**: `RocksDB corruption` 或 `IO error`

**解决方案**:
```bash
# 停止服务
docker compose down

# 删除 RocksDB 数据
rm -rf db/state_cache db/merkle_tree

# 重新启动
docker compose up -d
```

## 📚 与你的代码库的兼容性

### ❌ 不兼容的方式

你之前尝试的方式:
```bash
# 这不会工作
zksync_server --external-node
```

**原因**: `zksync_server` 不支持 `--external-node` 参数

### ✅ 正确的方式

使用独立的 `zksync_external_node` 二进制文件:
```bash
# 正确
zksync_external_node
```

## 🎯 推荐方案

基于你的情况,我推荐:

### 方案 A: 官方 External Node (推荐)

**优点**:
- ✅ 真正的节点副本
- ✅ 自动同步数据
- ✅ 主节点故障时仍可查询历史数据
- ✅ 符合官方架构

**缺点**:
- ❌ 需要构建镜像 (20-30 分钟)
- ❌ 需要同步时间 (1-10 小时)
- ❌ 需要更多存储空间

**部署命令**:
```bash
bash external_node/build_external_node.sh
bash external_node/deploy_official_external_node.sh
```

### 方案 B: Nginx 反向代理 (最简单)

**优点**:
- ✅ 5 分钟部署
- ✅ 无需构建
- ✅ 负载均衡
- ✅ 可添加缓存

**缺点**:
- ❌ 不是真正的节点
- ❌ 主节点故障时无法服务

**部署命令**:
```bash
bash external_node/deploy_nginx_proxy.sh
```

## 📖 参考资料

- [ZKsync External Node 官方文档](https://matter-labs.github.io/zksync-era/core/latest/guides/external-node/01_intro.html)
- [快速开始指南](https://matter-labs.github.io/zksync-era/core/latest/guides/external-node/00_quick_start.html)
- [配置说明](https://matter-labs.github.io/zksync-era/core/latest/guides/external-node/02_configuration.html)
- [运行指南](https://matter-labs.github.io/zksync-era/core/latest/guides/external-node/03_running.html)

## 🎉 总结

**关键要点**:
1. External Node 使用 `zksync_external_node` 二进制文件
2. 不是 `zksync_server --external-node`
3. 通过环境变量配置
4. 从主节点同步数据
5. 提供只读 API 服务

**下一步**:
1. 决定使用方案 A 还是方案 B
2. 执行相应的部署脚本
3. 验证部署
4. 监控同步进度
