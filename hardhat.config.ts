import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ETHERSCAN_KEY_ARB || "",
      optimisticEthereum: process.env.ETHERSCAN_KEY_OP || "",
      mainnet: process.env.ETHERSCAN_KEY || "",
    },
  },
  networks: {
    sst: {
      chainId: 534351,
      url: "https://sepolia-rpc.scroll.io/",
      // accounts: [pk],
    },
  },
};

export default config;
