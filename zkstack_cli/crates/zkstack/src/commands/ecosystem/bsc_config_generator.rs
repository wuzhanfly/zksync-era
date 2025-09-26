use anyhow::Result;
// use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use zkstack_cli_types::L1Network;

use super::bsc_wizard::BSCWizardConfig;

/// BSC配置生成器
pub struct BSCConfigGenerator {
    config: BSCWizardConfig,
    template_vars: HashMap<String, String>,
}

impl BSCConfigGenerator {
    pub fn new(config: BSCWizardConfig) -> Self {
        let mut generator = Self {
            config,
            template_vars: HashMap::new(),
        };
        generator.prepare_template_vars();
        generator
    }

    /// 准备模板变量
    fn prepare_template_vars(&mut self) {
        let config = &self.config;
        
        // 基本信息
        self.template_vars.insert("ecosystem_name".to_string(), config.ecosystem_name.clone());
        self.template_vars.insert("chain_name".to_string(), config.chain_name.clone());
        self.template_vars.insert("chain_id".to_string(), config.chain_id.to_string());
        
        // 网络信息
        let l1_network_str = match config.l1_network {
            L1Network::BSCMainnet => "bsc-mainnet",
            L1Network::BSCTestnet => "bsc-testnet",
            _ => "unknown",
        };
        self.template_vars.insert("l1_network".to_string(), l1_network_str.to_string());
        self.template_vars.insert("l1_chain_id".to_string(), config.l1_network.chain_id().to_string());
        self.template_vars.insert("rpc_url".to_string(), config.l1_rpc_url.clone());
        
        // 区块浏览器
        let block_explorer = config.l1_network.block_explorer_url().unwrap_or("").to_string();
        self.template_vars.insert("block_explorer".to_string(), block_explorer);
        
        // Gas配置
        self.template_vars.insert("base_gas_price".to_string(), config.gas_optimization.base_gas_price_gwei.to_string());
        self.template_vars.insert("max_gas_price".to_string(), config.gas_optimization.max_gas_price_gwei.to_string());
        self.template_vars.insert("gas_multiplier".to_string(), config.gas_optimization.gas_limit_multiplier_percent.to_string());
        
        // 钱包配置
        let wallet_creation = match config.wallet_creation {
            zkstack_cli_types::WalletCreation::Random => "Random",
            zkstack_cli_types::WalletCreation::InFile => "InFile",
            zkstack_cli_types::WalletCreation::Localhost => "Localhost",
            zkstack_cli_types::WalletCreation::Empty => "Empty",
        };
        self.template_vars.insert("wallet_creation".to_string(), wallet_creation.to_string());
        self.template_vars.insert("wallet_path".to_string(), config.wallet_path.clone().unwrap_or_default());
        
        // 部署配置
        self.template_vars.insert("deploy_ecosystem".to_string(), config.deploy_ecosystem.to_string());
        self.template_vars.insert("deploy_erc20".to_string(), config.deploy_erc20.to_string());
        self.template_vars.insert("deploy_paymaster".to_string(), config.deploy_paymaster.to_string());
        self.template_vars.insert("evm_emulator".to_string(), config.evm_emulator.to_string());
        
        // 性能配置
        self.template_vars.insert("tight_ports".to_string(), config.performance_config.tight_ports.to_string());
        self.template_vars.insert("no_port_reallocation".to_string(), config.performance_config.no_port_reallocation.to_string());
        self.template_vars.insert("start_containers".to_string(), config.performance_config.start_containers.to_string());
        self.template_vars.insert("update_submodules".to_string(), config.performance_config.update_submodules.to_string());
        
        // 开发配置
        self.template_vars.insert("dev_mode".to_string(), config.dev_mode.to_string());
        self.template_vars.insert("observability".to_string(), config.observability.to_string());
        
        // BSC特定配置
        let wbnb_address = match config.l1_network {
            L1Network::BSCMainnet => "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
            L1Network::BSCTestnet => "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
            _ => "0x0000000000000000000000000000000000000000",
        };
        self.template_vars.insert("wbnb_address".to_string(), wbnb_address.to_string());
        
        // 路径配置
        self.template_vars.insert("code_path".to_string(), ".".to_string());
        self.template_vars.insert("configs_path".to_string(), "./configs".to_string());
        self.template_vars.insert("db_path".to_string(), "./db".to_string());
        self.template_vars.insert("artifacts_path".to_string(), "./artifacts".to_string());
        
        // 其他配置
        self.template_vars.insert("prover_mode".to_string(), format!("{:?}", config.prover_mode));
        self.template_vars.insert("commit_mode".to_string(), "Rollup".to_string());
        self.template_vars.insert("legacy_bridge".to_string(), "false".to_string());
        self.template_vars.insert("validium_mode".to_string(), "Rollup".to_string());
        self.template_vars.insert("make_permanent_rollup".to_string(), "false".to_string());
        self.template_vars.insert("zksync_os".to_string(), "false".to_string());
        self.template_vars.insert("set_as_default".to_string(), "true".to_string());
        
        // Gas策略配置
        self.template_vars.insert("recommended_gas_price".to_string(), config.l1_network.recommended_gas_price_gwei().to_string());
        self.template_vars.insert("gas_limit_multiplier".to_string(), config.l1_network.gas_limit_multiplier().to_string());
    }

    /// 生成生态系统配置文件
    pub fn generate_ecosystem_config(&self, output_path: &Path) -> Result<()> {
        let template = include_str!("../../../../../../templates/bsc-ecosystem-config.toml");
        let config_content = self.replace_template_vars(template);
        
        fs::write(output_path, config_content)?;
        println!("✅ 生成生态系统配置: {}", output_path.display());
        
        Ok(())
    }

    /// 生成链配置文件
    pub fn generate_chain_config(&self, output_path: &Path) -> Result<()> {
        let template = include_str!("../../../../../../templates/bsc-chain-config.toml");
        let config_content = self.replace_template_vars(template);
        
        fs::write(output_path, config_content)?;
        println!("✅ 生成链配置: {}", output_path.display());
        
        Ok(())
    }

    /// 生成环境变量文件
    pub fn generate_env_file(&self, output_path: &Path) -> Result<()> {
        let env_content = self.generate_env_content();
        
        fs::write(output_path, env_content)?;
        println!("✅ 生成环境变量文件: {}", output_path.display());
        
        Ok(())
    }

    /// 生成Docker Compose配置
    pub fn generate_docker_compose(&self, output_path: &Path) -> Result<()> {
        let docker_content = self.generate_docker_compose_content();
        
        fs::write(output_path, docker_content)?;
        println!("✅ 生成Docker Compose配置: {}", output_path.display());
        
        Ok(())
    }

    /// 生成部署脚本
    pub fn generate_deployment_script(&self, output_path: &Path) -> Result<()> {
        let script_content = self.generate_deployment_script_content();
        
        fs::write(output_path, script_content)?;
        
        // 设置执行权限
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = fs::metadata(output_path)?.permissions();
            perms.set_mode(0o755);
            fs::set_permissions(output_path, perms)?;
        }
        
        println!("✅ 生成部署脚本: {}", output_path.display());
        
        Ok(())
    }

    /// 生成完整的配置包
    pub fn generate_full_config_package(&self, base_dir: &Path) -> Result<()> {
        // 创建目录结构
        fs::create_dir_all(base_dir)?;
        fs::create_dir_all(base_dir.join("configs"))?;
        fs::create_dir_all(base_dir.join("scripts"))?;
        fs::create_dir_all(base_dir.join("docker"))?;
        
        // 生成各种配置文件
        self.generate_ecosystem_config(&base_dir.join("ecosystem.toml"))?;
        self.generate_chain_config(&base_dir.join("configs").join("chain.toml"))?;
        self.generate_env_file(&base_dir.join(".env.bsc"))?;
        self.generate_docker_compose(&base_dir.join("docker").join("docker-compose.bsc.yml"))?;
        self.generate_deployment_script(&base_dir.join("scripts").join("deploy-bsc.sh"))?;
        
        // 生成README文件
        self.generate_readme(&base_dir.join("README.md"))?;
        
        println!("🎉 完整配置包生成完成: {}", base_dir.display());
        
        Ok(())
    }

    fn replace_template_vars(&self, template: &str) -> String {
        let mut content = template.to_string();
        
        for (key, value) in &self.template_vars {
            let placeholder = format!("{{{{{}}}}}", key);
            content = content.replace(&placeholder, value);
        }
        
        content
    }

    fn generate_env_content(&self) -> String {
        format!(r#"# BSC + ZKsync Era 环境配置
# 生成时间: {}

# 网络配置
L1_NETWORK={}
L1_CHAIN_ID={}
L1_RPC_URL={}
BLOCK_EXPLORER_URL={}

# 生态系统配置
ECOSYSTEM_NAME={}
CHAIN_NAME={}
CHAIN_ID={}

# Gas配置
BASE_GAS_PRICE_GWEI={}
MAX_GAS_PRICE_GWEI={}
GAS_LIMIT_MULTIPLIER={}

# BSC特定配置
WBNB_ADDRESS={}
MULTICALL3_ADDRESS=0xcA11bde05977b3631167028862bE2a173976CA11
SUPPORTS_EIP1559=false
AVERAGE_BLOCK_TIME=3

# 部署配置
DEPLOY_ECOSYSTEM={}
DEPLOY_ERC20={}
DEPLOY_PAYMASTER={}
EVM_EMULATOR={}

# 开发配置
DEV_MODE={}
OBSERVABILITY={}
"#,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
            self.template_vars.get("l1_network").unwrap(),
            self.template_vars.get("l1_chain_id").unwrap(),
            self.template_vars.get("rpc_url").unwrap(),
            self.template_vars.get("block_explorer").unwrap(),
            self.template_vars.get("ecosystem_name").unwrap(),
            self.template_vars.get("chain_name").unwrap(),
            self.template_vars.get("chain_id").unwrap(),
            self.template_vars.get("base_gas_price").unwrap(),
            self.template_vars.get("max_gas_price").unwrap(),
            self.template_vars.get("gas_limit_multiplier").unwrap(),
            self.template_vars.get("wbnb_address").unwrap(),
            self.template_vars.get("deploy_ecosystem").unwrap(),
            self.template_vars.get("deploy_erc20").unwrap(),
            self.template_vars.get("deploy_paymaster").unwrap(),
            self.template_vars.get("evm_emulator").unwrap(),
            self.template_vars.get("dev_mode").unwrap(),
            self.template_vars.get("observability").unwrap(),
        )
    }

    fn generate_docker_compose_content(&self) -> String {
        format!(r#"# BSC + ZKsync Era Docker Compose 配置
version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: zksync_local
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: notsecurepassword
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  zksync:
    image: matterlabs/zksync:latest
    depends_on:
      - postgres
    environment:
      - DATABASE_URL=postgres://postgres:notsecurepassword@postgres:5432/zksync_local
      - ETH_CLIENT_WEB3_URL={}
      - CHAIN_ETH_NETWORK={}
      - CHAIN_ETH_ZKSYNC_NETWORK_ID={}
    ports:
      - "3050:3050"
      - "3051:3051"
    volumes:
      - ./configs:/configs
      - ./artifacts:/artifacts

volumes:
  postgres_data:

networks:
  default:
    name: zksync-bsc-network
"#,
            self.template_vars.get("rpc_url").unwrap(),
            self.template_vars.get("l1_network").unwrap(),
            self.template_vars.get("chain_id").unwrap(),
        )
    }

    fn generate_deployment_script_content(&self) -> String {
        format!(r#"#!/bin/bash

# BSC + ZKsync Era 部署脚本
# 生成时间: {}

set -e

echo "🚀 开始部署BSC + ZKsync Era生态系统"
echo "====================================="

# 配置变量
ECOSYSTEM_NAME="{}"
L1_NETWORK="{}"
CHAIN_NAME="{}"
CHAIN_ID={}
RPC_URL="{}"

echo "📋 部署配置:"
echo "  生态系统名称: $ECOSYSTEM_NAME"
echo "  L1网络: $L1_NETWORK"
echo "  链名称: $CHAIN_NAME"
echo "  链ID: $CHAIN_ID"
echo "  RPC URL: $RPC_URL"
echo ""

# 检查依赖
echo "🔍 检查依赖..."
if ! command -v zkstack &> /dev/null; then
    echo "❌ zkstack CLI未找到，请先安装"
    exit 1
fi

# 创建生态系统
echo "🏗️ 创建生态系统..."
zkstack ecosystem create \
    --ecosystem-name "$ECOSYSTEM_NAME" \
    --l1-network "$L1_NETWORK" \
    --chain-name "$CHAIN_NAME" \
    --chain-id "$CHAIN_ID" \
    --prover-mode {} \
    --wallet-creation {} \
    --l1-batch-commit-data-generator-mode Rollup \
    --evm-emulator {} \
    --start-containers {}

# 进入生态系统目录
cd "$ECOSYSTEM_NAME"

# 初始化生态系统
echo "⚙️ 初始化生态系统..."
zkstack ecosystem init \
    --deploy-ecosystem {} \
    --deploy-erc20 {} \
    --deploy-paymaster {} \
    --observability {}

# 初始化链
echo "⛓️ 初始化链..."
zkstack chain init

# 启动服务器
if [ "{}" = "true" ]; then
    echo "🚀 启动服务器..."
    zkstack server run &
    SERVER_PID=$!
    echo "服务器PID: $SERVER_PID"
fi

echo ""
echo "🎉 部署完成!"
echo "============="
echo ""
echo "📁 生态系统目录: $ECOSYSTEM_NAME"
echo "🌐 L1网络: $L1_NETWORK"
echo "⛓️ 链名称: $CHAIN_NAME"
echo "🔗 链ID: $CHAIN_ID"
echo ""
echo "🚀 下一步操作:"
echo "  cd $ECOSYSTEM_NAME"
echo "  zkstack status        # 查看状态"
echo "  zkstack logs          # 查看日志"
echo "  zkstack explorer run  # 启动区块浏览器"
echo ""
echo "💡 有用的链接:"
echo "  BSC浏览器: {}"
echo "  BSC文档: https://docs.bnbchain.org"
echo "  ZKsync文档: https://docs.zksync.io"

if [ "$L1_NETWORK" = "bsc-testnet" ]; then
    echo "  BSC测试网水龙头: https://testnet.binance.org/faucet-smart"
fi

echo ""
echo "💰 成本优势 (vs 以太坊):"
echo "  • 交易费用降低 95%+"
echo "  • 部署成本降低 90%+"
echo "  • 确认时间提升 4倍"
"#,
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
            self.template_vars.get("ecosystem_name").unwrap(),
            self.template_vars.get("l1_network").unwrap(),
            self.template_vars.get("chain_name").unwrap(),
            self.template_vars.get("chain_id").unwrap(),
            self.template_vars.get("rpc_url").unwrap(),
            self.template_vars.get("prover_mode").unwrap(),
            self.template_vars.get("wallet_creation").unwrap(),
            self.template_vars.get("evm_emulator").unwrap(),
            self.template_vars.get("start_containers").unwrap(),
            self.template_vars.get("deploy_ecosystem").unwrap(),
            self.template_vars.get("deploy_erc20").unwrap(),
            self.template_vars.get("deploy_paymaster").unwrap(),
            self.template_vars.get("observability").unwrap(),
            self.template_vars.get("start_containers").unwrap(),
            self.template_vars.get("block_explorer").unwrap(),
        )
    }

    fn generate_readme(&self, output_path: &Path) -> Result<()> {
        let readme_content = format!(r#"# {} - BSC + ZKsync Era 生态系统

这是一个在BSC网络上运行的ZKsync Era L2扩容解决方案。

## 📋 配置信息

- **生态系统名称**: {}
- **L1网络**: {}
- **链名称**: {}
- **链ID**: {}
- **RPC URL**: {}

## 🚀 快速开始

### 1. 初始化生态系统
```bash
zkstack ecosystem init
```

### 2. 初始化链
```bash
zkstack chain init
```

### 3. 启动服务器
```bash
zkstack server run
```

## ⛽ Gas优化配置

- **策略类型**: Legacy (BSC不支持EIP-1559)
- **基础Gas价格**: {} Gwei
- **最大Gas价格**: {} Gwei
- **安全边际**: {}%

## 🌐 网络信息

- **链ID**: {}
- **原生代币**: BNB
- **区块时间**: 3秒
- **区块浏览器**: {}

## 💰 成本优势

相比以太坊主网，您将享受：
- 🔥 **95%+** 的交易费用节省
- ⚡ **4倍** 的交易确认速度
- 📈 **更高** 的网络吞吐量

## 🛠️ 有用的命令

```bash
# 查看状态
zkstack status

# 查看日志
zkstack logs

# 启动区块浏览器
zkstack explorer run

# 部署合约
zkstack contract deploy

# 管理钱包
zkstack wallet
```

## 📚 文档和资源

- [BSC官方文档](https://docs.bnbchain.org)
- [ZKsync官方文档](https://docs.zksync.io)
- [BSC区块浏览器]({})
{}

## 🔧 配置文件

- `ecosystem.toml` - 生态系统配置
- `configs/chain.toml` - 链配置
- `.env.bsc` - 环境变量
- `docker/docker-compose.bsc.yml` - Docker配置
- `scripts/deploy-bsc.sh` - 部署脚本

## 🆘 故障排除

### 常见问题

1. **Gas价格过高**
   - 检查当前网络状况
   - 调整Gas价格配置

2. **RPC连接失败**
   - 验证RPC URL是否正确
   - 检查网络连接

3. **部署失败**
   - 确保有足够的BNB余额
   - 检查合约代码

### 获取帮助

- 查看日志: `zkstack logs`
- 检查状态: `zkstack status`
- 重置配置: `zkstack reset`

---

生成时间: {}
配置版本: v1.0.0
"#,
            self.template_vars.get("ecosystem_name").unwrap(),
            self.template_vars.get("ecosystem_name").unwrap(),
            self.template_vars.get("l1_network").unwrap(),
            self.template_vars.get("chain_name").unwrap(),
            self.template_vars.get("chain_id").unwrap(),
            self.template_vars.get("rpc_url").unwrap(),
            self.template_vars.get("base_gas_price").unwrap(),
            self.template_vars.get("max_gas_price").unwrap(),
            self.template_vars.get("gas_multiplier").unwrap().parse::<u64>().unwrap_or(115) - 100,
            self.template_vars.get("l1_chain_id").unwrap(),
            self.template_vars.get("block_explorer").unwrap(),
            self.template_vars.get("block_explorer").unwrap(),
            if self.config.l1_network == L1Network::BSCTestnet {
                "- [BSC测试网水龙头](https://testnet.binance.org/faucet-smart)"
            } else {
                ""
            },
            chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC"),
        );

        fs::write(output_path, readme_content)?;
        println!("✅ 生成README文件: {}", output_path.display());
        
        Ok(())
    }
}