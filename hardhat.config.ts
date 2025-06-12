import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-viem";

const config: HardhatUserConfig = {
  solidity: "0.8.30",
  networks: {
    hardhat: {
      chainId: 31337,
    }
  }
};

export default config;