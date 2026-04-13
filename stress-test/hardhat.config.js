require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: "../.env.tmai" });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    tmaiChain: {
      url: "http://54.255.184.251:3050",
      chainId: 9720,
      accounts: [
        process.env.DEPLOYER_PRIVATE_KEY || process.env.OPERATOR_PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
      ],
      timeout: 120000,
      httpHeaders: {
        "Connection": "keep-alive"
      }
    },
  },
  mocha: {
    timeout: 120000,
  },
};
