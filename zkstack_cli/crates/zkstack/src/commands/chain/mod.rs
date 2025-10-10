use ::zkstack_cli_common::forge::ForgeScriptArgs;
use args::build_transactions::BuildTransactionsArgs;
pub(crate) use args::create::ChainCreateArgsFinal;
use clap::{command, Subcommand};
pub(crate) use create::create_chain_inner;
use set_da_validator_pair::SetDAValidatorPairArgs;
use set_da_validator_pair_calldata::SetDAValidatorPairCalldataArgs;
use set_transaction_filterer::SetTransactionFiltererArgs;
use xshell::Shell;

use crate::commands::chain::{
    args::{create::ChainCreateArgs, set_pubdata_pricing_mode::SetPubdataPricingModeArgs},
    deploy_l2_contracts::Deploy2ContractsOption,
    genesis::GenesisCommand,
    init::ChainInitCommand,
};

mod accept_chain_ownership;
pub(crate) mod admin_call_builder;
pub(crate) mod args;
mod bsc_optimization;
mod build_transactions;
pub(crate) mod common;
pub(crate) mod create;
pub mod deploy_l2_contracts;
pub mod deploy_paymaster;
mod enable_evm_emulator;
mod gateway;
pub mod genesis;
pub mod init;
pub mod register_chain;
mod set_da_validator_pair;
mod set_da_validator_pair_calldata;
mod set_pubdata_pricing_mode;
mod set_token_multiplier_setter;
pub(crate) mod set_transaction_filterer;
mod setup_legacy_bridge;
pub mod utils;

use bsc_optimization::{optimize_for_bsc, validate_bsc_config};

#[derive(Subcommand, Debug)]
pub enum ChainCommands {
    /// Create a new chain, setting the necessary configurations for later initialization
    Create(ChainCreateArgs),
    /// Create unsigned transactions for chain deployment
    BuildTransactions(BuildTransactionsArgs),
    /// Initialize chain, deploying necessary contracts and performing on-chain operations
    Init(Box<ChainInitCommand>),
    /// Run server genesis
    Genesis(GenesisCommand),
    /// Register a new chain on L1 (executed by L1 governor).
    /// This command deploys and configures Governance, ChainAdmin, and DiamondProxy contracts,
    /// registers chain with BridgeHub and sets pending admin for DiamondProxy.
    /// Note: After completion, L2 governor can accept ownership by running `accept-chain-ownership`
    #[command(alias = "register")]
    RegisterChain(ForgeScriptArgs),
    /// Deploy all L2 contracts (executed by L1 governor).
    #[command(alias = "l2")]
    DeployL2Contracts(ForgeScriptArgs),
    /// Accept ownership of L2 chain (executed by L2 governor).
    /// This command should be run after `register-chain` to accept ownership of newly created
    /// DiamondProxy contract.
    #[command(alias = "accept-ownership")]
    AcceptChainOwnership(ForgeScriptArgs),
    /// Deploy L2 consensus registry
    #[command(alias = "consensus")]
    DeployConsensusRegistry(ForgeScriptArgs),
    /// Deploy L2 multicall3
    #[command(alias = "multicall3")]
    DeployMulticall3(ForgeScriptArgs),
    /// Deploy L2 TimestampAsserter
    #[command(alias = "timestamp-asserter")]
    DeployTimestampAsserter(ForgeScriptArgs),
    /// Deploy L2 DA Validator
    #[command(alias = "da-validator")]
    DeployL2DAValidator(ForgeScriptArgs),
    /// Deploy Default Upgrader
    #[command(alias = "upgrader")]
    DeployUpgrader(ForgeScriptArgs),
    /// Deploy paymaster smart contract
    #[command(alias = "paymaster")]
    DeployPaymaster(ForgeScriptArgs),
    /// Update Token Multiplier Setter address on L1
    UpdateTokenMultiplierSetter(ForgeScriptArgs),
    /// Provides calldata to set transaction filterer for a chain
    SetTransactionFiltererCalldata(SetTransactionFiltererArgs),
    /// Provides calldata to set DA validator pair for a chain
    SetDAValidatorPairCalldata(SetDAValidatorPairCalldataArgs),
    /// Enable EVM emulation on chain (Not supported yet)
    EnableEvmEmulator(ForgeScriptArgs),
    /// Update pubdata pricing mode (used for Rollup -> Validium migration)
    SetPubdataPricingMode(SetPubdataPricingModeArgs),
    /// Update da validator pair (used for Rollup -> Validium migration)
    SetDAValidatorPair(SetDAValidatorPairArgs),
    #[command(subcommand, alias = "gw")]
    Gateway(gateway::GatewayComamnds),
    /// Optimize chain configuration for BSC network
    OptimizeForBsc {
        /// Chain name to optimize (optional, uses default if not specified)
        #[clap(long)]
        chain: Option<String>,
        /// BSC network type (mainnet or testnet)
        #[clap(long, default_value = "mainnet")]
        network_type: String,
        /// Apply optimizations immediately
        #[clap(long)]
        apply: bool,
        /// Output optimized configuration to file
        #[clap(long)]
        output: Option<String>,
    },
    /// Validate chain configuration for BSC compatibility
    ValidateBscConfig {
        /// Chain name to validate (optional, uses default if not specified)
        #[clap(long)]
        chain: Option<String>,
        /// Show detailed validation results
        #[clap(long)]
        detailed: bool,
    },
}

pub(crate) async fn run(shell: &Shell, args: ChainCommands) -> anyhow::Result<()> {
    match args {
        ChainCommands::Create(args) => create::run(args, shell).await,
        ChainCommands::Init(args) => init::run(*args, shell).await,
        ChainCommands::BuildTransactions(args) => build_transactions::run(args, shell).await,
        ChainCommands::Genesis(args) => genesis::run(args, shell).await,
        ChainCommands::RegisterChain(args) => register_chain::run(args, shell).await,
        ChainCommands::DeployL2Contracts(args) => {
            deploy_l2_contracts::run(args, shell, Deploy2ContractsOption::All).await
        }
        ChainCommands::AcceptChainOwnership(args) => accept_chain_ownership::run(args, shell).await,
        ChainCommands::DeployConsensusRegistry(args) => {
            deploy_l2_contracts::run(args, shell, Deploy2ContractsOption::ConsensusRegistry).await
        }
        ChainCommands::DeployMulticall3(args) => {
            deploy_l2_contracts::run(args, shell, Deploy2ContractsOption::Multicall3).await
        }
        ChainCommands::DeployTimestampAsserter(args) => {
            deploy_l2_contracts::run(args, shell, Deploy2ContractsOption::TimestampAsserter).await
        }
        ChainCommands::DeployL2DAValidator(args) => {
            deploy_l2_contracts::run(args, shell, Deploy2ContractsOption::L2DAValidator).await
        }
        ChainCommands::DeployUpgrader(args) => {
            deploy_l2_contracts::run(args, shell, Deploy2ContractsOption::Upgrader).await
        }
        ChainCommands::DeployPaymaster(args) => deploy_paymaster::run(args, shell).await,
        ChainCommands::UpdateTokenMultiplierSetter(args) => {
            set_token_multiplier_setter::run(args, shell).await
        }
        ChainCommands::SetTransactionFiltererCalldata(args) => {
            set_transaction_filterer::run(shell, args).await
        }
        ChainCommands::SetDAValidatorPairCalldata(args) => {
            set_da_validator_pair_calldata::run(shell, args).await
        }
        ChainCommands::EnableEvmEmulator(args) => enable_evm_emulator::run(args, shell).await,
        ChainCommands::SetPubdataPricingMode(args) => {
            set_pubdata_pricing_mode::run(args, shell).await
        }
        ChainCommands::SetDAValidatorPair(args) => set_da_validator_pair::run(args, shell).await,
        ChainCommands::Gateway(args) => gateway::run(shell, args).await,
        ChainCommands::OptimizeForBsc { chain, network_type, apply, output } => {
            optimize_for_bsc(shell, chain, network_type, apply, output).await
        }
        ChainCommands::ValidateBscConfig { chain, detailed } => {
            validate_bsc_config(shell, chain, detailed).await
        }
    }
}
