import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import * as dotenv from "dotenv";
import "hardhat-abi-exporter";
dotenv.config();
const pk = process.env.PRIVATE_KEY_SST || "";
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 999,
      },
    },
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ETHERSCAN_KEY_ARB || "",
      optimisticEthereum: process.env.ETHERSCAN_KEY_OP || "",
      mainnet: process.env.ETHERSCAN_KEY || "",
      sst: process.env.ETHERSCAN_KEY_SST || "",
    },
    customChains: [
      {
        network: "sst",
        chainId: 534351,
        urls: {
          apiURL: "https://api-sepolia.scrollscan.com/api",
          browserURL: "https://sepolia-rpc.scroll.io/",
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545/",
      // accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    sst: {
      chainId: 534351,
      url: "https://sepolia-rpc.scroll.io/",
      accounts: [pk],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
