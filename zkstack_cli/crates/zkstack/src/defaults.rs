use lazy_static::lazy_static;
use url::Url;
use zkstack_cli_config::ChainConfig;

lazy_static! {
    pub static ref DATABASE_SERVER_URL: Url =
        Url::parse("postgres://postgres:notsecurepassword@localhost:5432").unwrap();
    pub static ref DATABASE_PROVER_URL: Url =
        Url::parse("postgres://postgres:notsecurepassword@localhost:5432").unwrap();
    pub static ref DATABASE_EXPLORER_URL: Url =
        Url::parse("postgres://postgres:notsecurepassword@localhost:5432").unwrap();
    pub static ref DATABASE_PRIVATE_RPC_URL: Url =
        Url::parse("postgres://postgres:notsecurepassword@localhost:5432").unwrap();
    pub static ref AVAIL_RPC_URL: Url = Url::parse("wss://turing-rpc.avail.so/ws").unwrap();
    pub static ref AVAIL_BRIDGE_API_URL: Url =
        Url::parse("https://turing-bridge-api.avail.so").unwrap();
}

pub const DEFAULT_OBSERVABILITY_PORT: u16 = 3000;

// Default port range
pub const PORT_RANGE_START: u16 = 3000;
pub const PORT_RANGE_END: u16 = 5000;

pub const ROCKS_DB_STATE_KEEPER: &str = "state_keeper";
pub const ROCKS_DB_TREE: &str = "tree";
pub const ROCKS_DB_PROTECTIVE_READS: &str = "protective_reads";
pub const ROCKS_DB_BASIC_WITNESS_INPUT_PRODUCER: &str = "basic_witness_input_producer";
pub const EN_ROCKS_DB_PREFIX: &str = "en";
pub const MAIN_ROCKS_DB_PREFIX: &str = "main";

pub const L2_CHAIN_ID: u32 = 271;
/// Path to base chain configuration inside zksync-era
/// Local RPC url
pub(super) const LOCAL_RPC_URL: &str = "http://127.0.0.1:8545";

/// BSC Mainnet RPC URL
pub const BSC_MAINNET_RPC_URL: &str = "https://bsc-dataseed.binance.org/";

/// BSC Testnet RPC URL
pub const BSC_TESTNET_RPC_URL: &str = "https://bsc-testnet-dataseed.bnbchain.org";

/// BSC network specific configurations
pub mod bsc {
    /// BSC Mainnet WBNB token address
    pub const MAINNET_WBNB_ADDRESS: &str = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

    /// BSC Testnet WBNB token address
    pub const TESTNET_WBNB_ADDRESS: &str = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";

    /// BSC Multicall3 address (same on both networks)
    pub const MULTICALL3_ADDRESS: &str = "0xcA11bde05977b3631167028862bE2a173976CA11";

    /// BSC block time in seconds
    pub const BLOCK_TIME_SECONDS: u64 = 3;

    /// BSC gas price scale factor for mainnet
    pub const MAINNET_GAS_PRICE_SCALE_FACTOR: f64 = 1.2;

    /// BSC gas price scale factor for testnet
    pub const TESTNET_GAS_PRICE_SCALE_FACTOR: f64 = 1.1;

    /// BSC max gas price for mainnet (20 Gwei)
    pub const MAINNET_MAX_GAS_PRICE: u64 = 20_000_000_000;

    /// BSC max gas price for testnet (10 Gwei)
    pub const TESTNET_MAX_GAS_PRICE: u64 = 10_000_000_000;
}

pub struct DBNames {
    pub server_name: String,
    pub prover_name: String,
}

pub fn generate_db_names(config: &ChainConfig) -> DBNames {
    let network_name = config.l1_network.to_string().to_ascii_lowercase().replace('-', "_");
    DBNames {
        server_name: format!(
            "zksync_server_{}_{}",
            network_name,
            config.name
        ),
        prover_name: format!(
            "zksync_prover_{}_{}",
            network_name,
            config.name
        ),
    }
}

pub fn generate_private_rpc_db_name(config: &ChainConfig) -> String {
    let network_name = config.l1_network.to_string().to_ascii_lowercase().replace('-', "_");
    format!(
        "zksync_private_rpc_{}_{}",
        network_name,
        config.name
    )
}

pub fn generate_explorer_db_name(config: &ChainConfig) -> String {
    let network_name = config.l1_network.to_string().to_ascii_lowercase().replace('-', "_");
    format!(
        "zksync_explorer_{}_{}",
        network_name,
        config.name
    )
}

pub fn generate_external_node_db_name(config: &ChainConfig) -> String {
    let network_name = config.l1_network.to_string().to_ascii_lowercase().replace('-', "_");
    format!(
        "external_node_{}_{}",
        network_name,
        config.name
    )
}
