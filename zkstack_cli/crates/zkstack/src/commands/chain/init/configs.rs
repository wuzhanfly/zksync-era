use anyhow::Context;
use xshell::Shell;
use zkstack_cli_common::logger;
use zkstack_cli_config::{
    copy_configs, ChainConfig, ConsensusGenesisSpecs, RawConsensusKeys, Weighted, ZkStackConfig,
    ZkStackConfigTrait,
};
use zkstack_cli_types::L1Network;

use crate::{
    commands::{
        chain::{
            args::init::{
                configs::{InitConfigsArgs, InitConfigsArgsFinal},
                da_configs::ValidiumType,
            },
            genesis,
        },
        portal::update_portal_config,
    },
    messages::{MSG_CHAIN_CONFIGS_INITIALIZED, MSG_PORTAL_FAILED_TO_CREATE_CONFIG_ERR},
    utils::ports::EcosystemPortsScanner,
};

pub async fn run(args: InitConfigsArgs, shell: &Shell) -> anyhow::Result<()> {
    let chain_config = ZkStackConfig::current_chain(shell)?;
    let args = args.fill_values_with_prompt(&chain_config);

    init_configs(&args, shell, &chain_config).await?;
    logger::outro(MSG_CHAIN_CONFIGS_INITIALIZED);

    Ok(())
}

pub async fn init_configs(
    init_args: &InitConfigsArgsFinal,
    shell: &Shell,
    chain_config: &ChainConfig,
) -> anyhow::Result<()> {
    // Port scanner should run before copying configs to avoid marking initial ports as assigned
    let mut ecosystem_ports = EcosystemPortsScanner::scan(shell, Some(&chain_config.name))?;
    copy_configs(
        shell,
        &chain_config.default_configs_path(),
        &chain_config.configs,
    )?;

    if !init_args.no_port_reallocation {
        ecosystem_ports.allocate_ports_in_yaml(
            shell,
            &chain_config.path_to_general_config(),
            chain_config.id,
            chain_config.tight_ports,
        )?;
    }

    // Initialize genesis config
    let mut genesis_config = chain_config.get_genesis_config().await?.patched();
    genesis_config.update_from_chain_config(chain_config)?;
    genesis_config.save().await?;

    let Ok(general_config) = chain_config.get_general_config().await else {
        // If general config does not exist, we don't need to patch it.
        return Ok(());
    };

    let prover_data_handler_url = general_config.proof_data_handler_url()?;
    let tee_prover_data_handler_url = general_config.tee_proof_data_handler_url()?;
    let prover_gateway_url = general_config.prover_gateway_url()?;

    let consensus_keys = RawConsensusKeys::generate();

    let mut general_config = general_config.patched();
    if let Some(url) = prover_data_handler_url {
        general_config.set_prover_gateway_url(url)?;
    }
    if let Some(url) = tee_prover_data_handler_url {
        general_config.set_tee_prover_gateway_url(url)?;
    }
    if let Some(url) = prover_gateway_url {
        general_config.set_proof_data_handler_url(url)?;
    }

    general_config.set_consensus_specs(ConsensusGenesisSpecs {
        chain_id: chain_config.chain_id,
        validators: vec![Weighted {
            key: consensus_keys.validator_public.clone(),
            weight: 1,
        }],
        leader: consensus_keys.validator_public.clone(),
    })?;

    match &init_args.validium_config {
        None | Some(ValidiumType::NoDA) | Some(ValidiumType::EigenDA) => {
            general_config.remove_da_client();
        }
        Some(ValidiumType::Avail((avail_config, _))) => {
            general_config.set_avail_client(avail_config)?;
        }
    }
    general_config.save().await?;

    // 🚀 智能网络配置优化: 根据L1网络类型自动应用最优配置
    apply_network_optimized_config(shell, chain_config).await?;

    // Initialize genesis config
    let mut genesis_config = chain_config.get_genesis_config().await?.patched();
    genesis_config.update_from_chain_config(chain_config)?;
    genesis_config.save().await?;

    // Initialize secrets config
    let mut secrets = chain_config.get_secrets_config().await?.patched();
    secrets.set_l1_rpc_url(init_args.l1_rpc_url.clone())?;
    secrets.set_consensus_keys(consensus_keys)?;
    match &init_args.validium_config {
        None | Some(ValidiumType::NoDA) | Some(ValidiumType::EigenDA) => { /* Do nothing */ }
        Some(ValidiumType::Avail((_, avail_secrets))) => {
            secrets.set_avail_secrets(avail_secrets)?;
        }
    }
    secrets.save().await?;

    let override_validium_config = false; // We've initialized validium params above.
    if let Some(genesis_args) = &init_args.genesis_args {
        // Initialize genesis database if needed
        genesis::database::update_configs(
            genesis_args,
            shell,
            chain_config,
            override_validium_config,
        )
        .await?;
    }

    update_portal_config(shell, chain_config)
        .await
        .context(MSG_PORTAL_FAILED_TO_CREATE_CONFIG_ERR)?;

    Ok(())
}

/// 智能网络配置优化
/// 根据L1网络类型自动应用最优的general.yaml配置
async fn apply_network_optimized_config(
    shell: &Shell,
    chain_config: &ChainConfig,
) -> anyhow::Result<()> {
    logger::info("🔍 检测L1网络类型并应用优化配置...");
    
    // 获取生态系统配置以确定L1网络类型
    let ecosystem_config = ZkStackConfig::ecosystem(shell)?;
    let l1_network = ecosystem_config.l1_network;
    
    match l1_network {
        L1Network::BscMainnet | L1Network::BscTestnet => {
            logger::info("🚀 检测到BSC网络，应用BSC优化配置...");
            apply_bsc_optimized_general_config(shell, chain_config, l1_network).await?;
        }
        L1Network::Mainnet | L1Network::Sepolia | L1Network::Holesky => {
            logger::info("🔧 检测到以太坊网络，应用以太坊优化配置...");
            apply_ethereum_optimized_general_config(shell, chain_config, l1_network).await?;
        }
        L1Network::Localhost => {
            logger::info("🏠 检测到本地网络，使用默认配置...");
            // 本地网络使用默认配置，无需特殊优化
        }
    }
    
    Ok(())
}

/// 应用BSC优化的general.yaml配置
async fn apply_bsc_optimized_general_config(
    shell: &Shell,
    chain_config: &ChainConfig,
    l1_network: L1Network,
) -> anyhow::Result<()> {
    let general_config_path = chain_config.path_to_general_config();
    
    // 读取BSC优化模板
    let bsc_template_path = "etc/env/file_based/general_bsc_optimized.yaml";
    
    if !shell.path_exists(bsc_template_path) {
        logger::warn("⚠️  BSC优化模板不存在，使用内置配置...");
        return apply_bsc_config_inline(shell, chain_config, l1_network).await;
    }
    
    // 创建原配置备份
    let backup_path = format!("{}.pre_bsc_backup", general_config_path.display());
    shell.copy_file(&general_config_path, &backup_path)?;
    
    // 读取BSC优化模板
    let bsc_template_content = shell.read_file(bsc_template_path)?;
    
    // 应用BSC优化配置
    shell.write_file(&general_config_path, &bsc_template_content)?;
    
    logger::success(&format!(
        "✅ BSC优化配置已应用 (网络: {:?})", 
        l1_network
    ));
    logger::info(&format!("📋 原配置备份: {}", backup_path));
    
    Ok(())
}

/// 应用以太坊优化的general.yaml配置
async fn apply_ethereum_optimized_general_config(
    shell: &Shell,
    chain_config: &ChainConfig,
    l1_network: L1Network,
) -> anyhow::Result<()> {
    let general_config_path = chain_config.path_to_general_config();
    
    // 读取现有配置
    let existing_content = shell.read_file(&general_config_path)?;
    let mut general_config: serde_yaml::Value = serde_yaml::from_str(&existing_content)
        .with_context(|| "无法解析general.yaml文件")?;
    
    // 应用以太坊网络优化
    apply_ethereum_optimizations(&mut general_config, l1_network)?;
    
    // 写入优化后的配置
    let optimized_content = serde_yaml::to_string(&general_config)
        .with_context(|| "无法序列化优化后的配置")?;
    
    shell.write_file(&general_config_path, &optimized_content)?;
    
    logger::success(&format!(
        "✅ 以太坊优化配置已应用 (网络: {:?})", 
        l1_network
    ));
    
    Ok(())
}

/// 内联应用BSC配置 (当模板文件不存在时)
async fn apply_bsc_config_inline(
    shell: &Shell,
    chain_config: &ChainConfig,
    l1_network: L1Network,
) -> anyhow::Result<()> {
    let general_config_path = chain_config.path_to_general_config();
    
    // 读取现有配置
    let existing_content = shell.read_file(&general_config_path)?;
    let mut general_config: serde_yaml::Value = serde_yaml::from_str(&existing_content)
        .with_context(|| "无法解析general.yaml文件")?;
    
    // 应用BSC优化
    apply_bsc_optimizations_inline(&mut general_config, l1_network)?;
    
    // 写入优化后的配置
    let optimized_content = serde_yaml::to_string(&general_config)
        .with_context(|| "无法序列化优化后的配置")?;
    
    shell.write_file(&general_config_path, &optimized_content)?;
    
    logger::success(&format!(
        "✅ BSC内联优化配置已应用 (网络: {:?})", 
        l1_network
    ));
    
    Ok(())
}

/// 应用以太坊网络优化
fn apply_ethereum_optimizations(
    config: &mut serde_yaml::Value,
    l1_network: L1Network,
) -> anyhow::Result<()> {
    let config_map = config.as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("配置文件格式错误"))?;
    
    // 以太坊网络优化配置
    let eth_config = config_map.entry("eth".into())
        .or_insert_with(|| serde_yaml::Value::Mapping(serde_yaml::Mapping::new()))
        .as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("eth配置格式错误"))?;
    
    // 以太坊Sender配置
    let sender_config = eth_config.entry("sender".into())
        .or_insert_with(|| serde_yaml::Value::Mapping(serde_yaml::Mapping::new()))
        .as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("sender配置格式错误"))?;
    
    match l1_network {
        L1Network::Mainnet => {
            // 主网: 保守配置
            sender_config.insert("max_acceptable_priority_fee_in_gwei".into(), 
                serde_yaml::Value::Number(100_000_000_000u64.into())); // 100 Gwei
            sender_config.insert("aggregated_block_commit_deadline".into(), 
                serde_yaml::Value::Number(300.into())); // 5分钟
        }
        L1Network::Sepolia | L1Network::Holesky => {
            // 测试网: 适中配置
            sender_config.insert("max_acceptable_priority_fee_in_gwei".into(), 
                serde_yaml::Value::Number(50_000_000_000u64.into())); // 50 Gwei
            sender_config.insert("aggregated_block_commit_deadline".into(), 
                serde_yaml::Value::Number(120.into())); // 2分钟
        }
        _ => {}
    }
    
    logger::info(&format!("✅ 以太坊网络优化已应用: {:?}", l1_network));
    Ok(())
}

/// 内联应用BSC优化配置
fn apply_bsc_optimizations_inline(
    config: &mut serde_yaml::Value,
    l1_network: L1Network,
) -> anyhow::Result<()> {
    let config_map = config.as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("配置文件格式错误"))?;
    
    // ETH配置优化
    let eth_config = config_map.entry("eth".into())
        .or_insert_with(|| serde_yaml::Value::Mapping(serde_yaml::Mapping::new()))
        .as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("eth配置格式错误"))?;
    
    // Sender配置
    let sender_config = eth_config.entry("sender".into())
        .or_insert_with(|| serde_yaml::Value::Mapping(serde_yaml::Mapping::new()))
        .as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("sender配置格式错误"))?;
    
    sender_config.insert("max_txs_in_flight".into(), serde_yaml::Value::Number(50.into()));
    sender_config.insert("max_acceptable_priority_fee_in_gwei".into(), 
        serde_yaml::Value::Number(5_000_000_000u64.into())); // 5 Gwei
    sender_config.insert("aggregated_block_commit_deadline".into(), 
        serde_yaml::Value::Number(3.into())); // 3秒
    sender_config.insert("pubdata_sending_mode".into(),
        serde_yaml::Value::String("BLOBS".to_string()));
    
    // Watcher配置
    let watcher_config = eth_config.entry("watcher".into())
        .or_insert_with(|| serde_yaml::Value::Mapping(serde_yaml::Mapping::new()))
        .as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("watcher配置格式错误"))?;
    
    watcher_config.insert("confirmations_for_eth_event".into(), 
        serde_yaml::Value::Number(2.into()));
    watcher_config.insert("eth_node_poll_interval".into(), 
        serde_yaml::Value::Number(1500.into()));
    
    // State Keeper配置
    let state_keeper_config = config_map.entry("state_keeper".into())
        .or_insert_with(|| serde_yaml::Value::Mapping(serde_yaml::Mapping::new()))
        .as_mapping_mut()
        .ok_or_else(|| anyhow::anyhow!("state_keeper配置格式错误"))?;
    
    state_keeper_config.insert("block_commit_deadline_ms".into(), 
        serde_yaml::Value::Number(3000.into()));
    state_keeper_config.insert("miniblock_commit_deadline_ms".into(), 
        serde_yaml::Value::Number(1000.into()));
    
    // BSC费用优化配置
    let mut bsc_fee_config = serde_yaml::Mapping::new();
    bsc_fee_config.insert("enabled".into(), serde_yaml::Value::Bool(true));
    bsc_fee_config.insert("min_base_fee_gwei".into(), 
        serde_yaml::Value::Number(0.1.into()));
    bsc_fee_config.insert("max_base_fee_gwei".into(), 
        serde_yaml::Value::Number(5.0.into()));
    bsc_fee_config.insert("target_base_fee_gwei".into(), 
        serde_yaml::Value::Number(1.0.into()));
    bsc_fee_config.insert("network_type".into(), 
        serde_yaml::Value::String(format!("{:?}", l1_network).to_lowercase()));
    
    config_map.insert("bsc_fee_optimization".into(), 
        serde_yaml::Value::Mapping(bsc_fee_config));
    
    logger::info(&format!("✅ BSC内联优化已应用: {:?}", l1_network));
    Ok(())
}
