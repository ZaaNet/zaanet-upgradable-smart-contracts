import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@openzeppelin/hardhat-upgrades";
import dotenv from "dotenv";
dotenv.config();

const { ALCHEMY_API_KEY, PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    arbitrumSepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY.replace('0x', '')}`] : [],
      chainId: 421614,
      gasPrice: 100000000,
      gas: 10000000,
    },
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL || `https://base-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY.replace('0x', '')}`] : [],
      chainId: 84532,
    },
    arbitrumOne: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY.replace('0x', '')}`] : [],
      chainId: 42161,
      gasPrice: 100000000,
    },
  },
  etherscan: {
    apiKey: {
      // Use Etherscan API key for all networks as Etherscan V2 API supports multiple chains
      arbitrumOne: ETHERSCAN_API_KEY || "",
      arbitrumSepolia: ETHERSCAN_API_KEY || "",
      baseSepolia: process.env.BASESCAN_API_KEY || ETHERSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "arbitrumOne",
        chainId: 42161,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=42161",
          browserURL: "https://arbiscan.io",
        },
      },
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=421614",
          browserURL: "https://sepolia.arbiscan.io",
        },
      },
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=84532",
          browserURL: "https://sepolia.basescan.org",
        },
      },
    ],
  },
  ignition: {
    requiredConfirmations: process.env.IGNITION_CONFIRMATIONS
      ? parseInt(process.env.IGNITION_CONFIRMATIONS, 10)
      : 1,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
};

export default config;
