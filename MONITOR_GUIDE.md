# BSC 节点监控脚本使用指南

## 问题分析

原始 `test.py` 文件存在严重问题：

### 🔴 严重问题

1. **代码格式损坏** - 大量重复和混乱的代码，无法执行
2. **安全风险** - Telegram Token 硬编码在代码中
3. **资源泄漏** - Session 对象未正确关闭

### 修复方案

已创建 `test_fixed.py` 修复所有问题。

## 功能特性

### 监控能力

- ✅ 本地节点区块高度监控
- ✅ 与官方节点对比
- ✅ 高度无变化告警（连续 5 次）
- ✅ 高度落后告警（落后 > 3 个区块）
- ✅ 节点恢复通知
- ✅ Telegram 实时告警

### 技术特性

- ✅ 自动重试机制
- ✅ 完整日志记录
- ✅ 环境变量配置
- ✅ 优雅退出
- ✅ 异常处理

## 安装依赖

```bash
pip install requests urllib3
```

## 配置

### 方法 1: 使用环境变量文件（推荐）

1. 复制配置模板：
```bash
cp .env.monitor .env.monitor.local
```

2. 编辑配置：
```bash
nano .env.monitor.local
```

3. 填写 Telegram 配置：
```bash
TELEGRAM_BOT_TOKEN=6337676047:你的真实Token
TELEGRAM_CHAT_ID=你的真实ChatID
```

### 方法 2: 直接设置环境变量

```bash
export TELEGRAM_BOT_TOKEN="你的Token"
export TELEGRAM_CHAT_ID="你的ChatID"
export LOCAL_NODE_URL="http://127.0.0.1:10575"
export OFFICIAL_NODE_URL="https://bsc-testnet-dataseed.bnbchain.org"
export CHECK_INTERVAL=10
export MAX_NO_CHANGE_COUNT=5
export MAX_HEIGHT_DIFF=3
```

## 获取 Telegram 配置

### 1. 创建 Bot

1. 在 Telegram 中搜索 `@BotFather`
2. 发送 `/newbot` 创建新 Bot
3. 按提示设置名称
4. 获得 Bot Token（格式：`123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`）

### 2. 获取 Chat ID

1. 在 Telegram 中搜索你的 Bot
2. 发送任意消息给 Bot
3. 访问：`https://api.telegram.org/bot<你的Token>/getUpdates`
4. 在返回的 JSON 中找到 `"chat":{"id":123456789}`

## 使用方法

### 前台运行（测试）

```bash
# 使用环境变量文件
source .env.monitor.local
python3 test_fixed.py

# 或直接运行
TELEGRAM_BOT_TOKEN="你的Token" \
TELEGRAM_CHAT_ID="你的ChatID" \
python3 test_fixed.py
```

### 后台运行（生产）

```bash
# 使用 nohup
source .env.monitor.local
nohup python3 test_fixed.py > monitor.log 2>&1 &

# 查看日志
tail -f monitor.log
tail -f bsc_monitor.log

# 停止监控
ps aux | grep test_fixed.py
kill <PID>
```

### 使用 systemd（推荐）

1. 创建服务文件：
```bash
sudo nano /etc/systemd/system/bsc-monitor.service
```

2. 添加内容：
```ini
[Unit]
Description=BSC Node Monitor
After=network.target

[Service]
Type=simple
User=你的用户名
WorkingDirectory=/path/to/zksync-era
Environment="TELEGRAM_BOT_TOKEN=你的Token"
Environment="TELEGRAM_CHAT_ID=你的ChatID"
Environment="LOCAL_NODE_URL=http://127.0.0.1:10575"
Environment="OFFICIAL_NODE_URL=https://bsc-testnet-dataseed.bnbchain.org"
ExecStart=/usr/bin/python3 /path/to/zksync-era/test_fixed.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. 启动服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable bsc-monitor
sudo systemctl start bsc-monitor

# 查看状态
sudo systemctl status bsc-monitor

# 查看日志
sudo journalctl -u bsc-monitor -f
```

## 告警类型

### 1. 高度无变化告警

**触发条件**：连续 5 次检查（50 秒）本地节点高度无变化

**消息示例**：
```
⚠️ BSC节点高度无变化告警 ⚠️

节点地址: http://127.0.0.1:10575
本地高度: 12345678
官方高度: 12345690
高度差: 12
连续 5 次检查高度无变化
监控开始时间: 2024-01-01 10:00:00
告警时间: 2024-01-01 10:01:00

请检查本地节点是否正常运行或同步！
```

### 2. 高度落后告警

**触发条件**：本地节点落后官方节点超过 3 个区块

**消息示例**：
```
⚠️ BSC节点高度落后告警 ⚠️

节点地址: http://127.0.0.1:10575
本地高度: 12345678
官方高度: 12345685
高度差: 7
本地节点落后官方节点 7 个区块（阈值: 3）
监控开始时间: 2024-01-01 10:00:00
告警时间: 2024-01-01 10:01:00

请检查本地节点是否正常运行或同步！
```

### 3. 节点恢复通知

**触发条件**：节点从异常状态恢复正常

**消息示例**：
```
✅ BSC本地节点已恢复正常

节点地址: http://127.0.0.1:10575
本地高度: 12345690
官方高度: 12345692
高度差: 2
恢复时间: 2024-01-01 10:05:00
```

### 4. 节点异常告警

**触发条件**：无法连接到本地节点

**消息示例**：
```
❌ BSC本地节点异常

节点地址: http://127.0.0.1:10575
时间: 2024-01-01 10:00:00
无法获取区块高度，请检查节点服务！
```

## 配置参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `CHECK_INTERVAL` | 10 | 检查间隔（秒） |
| `MAX_NO_CHANGE_COUNT` | 5 | 连续无变化告警阈值 |
| `MAX_HEIGHT_DIFF` | 3 | 高度落后告警阈值（区块数） |
| `LOCAL_NODE_URL` | http://127.0.0.1:10575 | 本地节点 RPC 地址 |
| `OFFICIAL_NODE_URL` | https://bsc-testnet-dataseed.bnbchain.org | 官方节点 RPC 地址 |

## 日志文件

- `bsc_monitor.log` - 监控日志（脚本自动创建）
- `monitor.log` - 标准输出日志（nohup 创建）

## 故障排查

### 问题 1: 无法连接到本地节点

**症状**：
```
ERROR - 请求本地节点失败: Connection refused
```

**解决方法**：
1. 检查节点是否运行：`ps aux | grep node`
2. 检查端口是否监听：`netstat -tlnp | grep 10575`
3. 检查防火墙：`sudo ufw status`

### 问题 2: Telegram 告警未发送

**症状**：
```
WARNING - Telegram配置未设置，跳过发送告警
```

**解决方法**：
1. 确认环境变量已设置：`echo $TELEGRAM_BOT_TOKEN`
2. 测试 Bot Token：
```bash
curl "https://api.telegram.org/bot<你的Token>/getMe"
```

### 问题 3: 官方节点连接失败

**症状**：
```
WARNING - 获取官方节点高度失败，跳过对比
```

**解决方法**：
1. 检查网络连接
2. 尝试其他官方节点：
   - `https://bsc-dataseed.binance.org`
   - `https://bsc-dataseed1.defibit.io`
   - `https://bsc-dataseed1.ninicoin.io`

### 问题 4: 脚本意外退出

**症状**：
```
ERROR - 监控循环发生未预期异常
```

**解决方法**：
1. 查看完整日志：`tail -100 bsc_monitor.log`
2. 使用 systemd 自动重启
3. 检查 Python 依赖：`pip list | grep requests`

## 性能优化

### 减少检查频率

如果节点稳定，可以降低检查频率：

```bash
export CHECK_INTERVAL=30  # 30秒检查一次
```

### 调整告警阈值

根据实际情况调整：

```bash
export MAX_NO_CHANGE_COUNT=10  # 更宽松的无变化阈值
export MAX_HEIGHT_DIFF=10      # 更宽松的落后阈值
```

## 安全建议

1. ✅ **不要**将 Telegram Token 提交到 Git
2. ✅ 使用 `.gitignore` 排除配置文件：
```bash
echo ".env.monitor.local" >> .gitignore
```

3. ✅ 定期轮换 Bot Token
4. ✅ 限制 Bot 权限（只需发送消息）
5. ✅ 使用专用的监控 Bot

## 对比原始脚本

| 特性 | 原始 test.py | 修复后 test_fixed.py |
|------|-------------|---------------------|
| 代码格式 | ❌ 损坏 | ✅ 正常 |
| 安全性 | ❌ Token 泄露 | ✅ 环境变量 |
| 资源管理 | ❌ Session 泄漏 | ✅ 正确关闭 |
| 错误处理 | ⚠️ 部分 | ✅ 完整 |
| 配置灵活性 | ❌ 硬编码 | ✅ 环境变量 |
| 可执行性 | ❌ 无法运行 | ✅ 正常运行 |

## 总结

修复后的脚本已经可以正常使用。主要改进：

1. ✅ 修复所有代码格式错误
2. ✅ 使用环境变量保护敏感信息
3. ✅ 添加资源清理机制
4. ✅ 完善错误处理
5. ✅ 提供完整配置说明

建议使用 `test_fixed.py` 替代原始的 `test.py`。
