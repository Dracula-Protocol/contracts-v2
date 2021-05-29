import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
const fs = require('fs');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();
  const POOL_JSON = __dirname + '/data/pools.json';
  const POOL_ID = 'pickle';

  let { deployer, WETH, sushiFactory } = await getNamedAccounts();

  if (chainId === '31337') {
    return;
  }

  if (chainId == '1') {
    const MasterVampire = await deployments.get('MasterVampire');
    const masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, ethers.provider.getSigner(deployer));

    const PickleAdapter = await deploy('PickleAdapter', {
      from: deployer,
      log: true,
      contract: 'PickleAdapter',
      args: [WETH, sushiFactory, masterVampire.address]
    });

    if (PickleAdapter.newlyDeployed) {
      const data = fs.readFileSync(POOL_JSON);
      const pools = JSON.parse(data);

      let nextPID = (await masterVampire.poolLength()).toNumber();
      for (let pool of pools[POOL_ID].victimPools) {
        await masterVampire.add(PickleAdapter.address, pool.victimPID);
        if (pool.pid == undefined) {
          pool.pid = nextPID;
          nextPID++;
        }
      }

      pools[POOL_ID].deployedAdapter = PickleAdapter.address;

      fs.writeFileSync(POOL_JSON, JSON.stringify(pools, null, 2));
    }
  }
};

export default func;
func.tags = ['dracula', 'live'];
