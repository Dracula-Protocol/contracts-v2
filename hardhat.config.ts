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
import "hardhat-abi-exporter";


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
  abiExporter: {
    clear: true,
  },
  networks: {
    hardhat: {
      loggingEnabled: false,
      /*forking: {
        url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`
      }*/
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
  },
  namedAccounts: {
    alice: {
      default: 2,
      1: '0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE'
    },
    bob: {
      default: 3,
      1: '0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE'
    },
    carol: {
      default: 4,
      1: '0x3f5CE5FBFe3E9af3971dD833D26bA9b5C936f0bE'
    },
    chi: {
      1: '0x0000000000004946c0e9F43F4Dee607b0eF1fA1c'
    },
    DAI: {
      1: '0x6B175474E89094C44Da98b954EedeAC495271d0F'
    },
    DRCETHUNI: {
      1: '0x276E62C70e0B540262491199Bc1206087f523AF6'
    },
    DRCETHYFL: {
      1: '0xcEf225FE69B9B9c26c12f615581d4f77F44ECd2d'
    },
    deployer: {
      default: 0,
      1: '0x94627695F66Ab36Ae00c1995a30Bf5B30E139873',
      42: '0x94627695F66Ab36Ae00c1995a30Bf5B30E139873'
    },
    DRC: {
      1: '0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8'
    },
    treasury: {
      default: 1,
      1: '0xa896e4bd97a733F049b23d2AcEB091BcE01f298d',
      42: '0xa896e4bd97a733F049b23d2AcEB091BcE01f298d'
    },
    rariFundManager: {
      1: '0xD6e194aF3d9674b62D1b30Ec676030C23961275e'
    },
    sushirouter: {
      1: '0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F',
      42: '0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F'
    },
    unirouter: {
      1: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D',
      42: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
    },
    uniFactory: {
      1: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
      42: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'
    },
    USDC: {
      1: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
    },
    USDT: {
      1: '0xdAC17F958D2ee523a2206206994597C13D831ec7'
    },
    WETH: {
      1: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
    },
  }
};

export default config;