import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
dotenv.config({ path: __dirname + '/.env' });

import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import "hardhat-typechain";
import "hardhat-gas-reporter";
import "solidity-coverage";


const INFURA_API_KEY = `${process.env.INFURA_API_KEY}`;
const KOVAN_PRIVATE_KEY = `${process.env.KOVAN_PRIVATE_KEY}`;
const MAINNET_PRIVATE_KEY = `${process.env.MAINNET_PRIVATE_KEY}`;
const ETHERSCAN_API_KEY = `${process.env.ETHERSCAN_API_KEY}`;
const CMC_API_KEY = `${process.env.CMC_API_KEY}`;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999
      }
    }
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5"
  },
  mocha: {
    timeout: 120000
  },
  gasReporter: {
    enabled: false,
    currency: 'USD',
    gasPrice: 60,
    coinmarketcap: `${CMC_API_KEY}`
  },
  networks: {
    hardhat: {
      loggingEnabled: false,
      forking: {
        url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`
      }
    },
    localhost: {
      url: "http://127.0.0.1:8546"
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [KOVAN_PRIVATE_KEY]
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [MAINNET_PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};

export default config;