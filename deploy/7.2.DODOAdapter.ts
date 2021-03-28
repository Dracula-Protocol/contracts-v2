import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
const fs = require('fs');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();
  const POOL_JSON = __dirname + '/data/pools.json';
  const POOL_ID = 'dodo';

  let { deployer, WETH, uniFactory } = await getNamedAccounts();

  if (chainId == '1') {
    const MasterVampire = await deployments.get('MasterVampire');

    const DODOAdapter = await deploy('DODOAdapter', {
      from: deployer,
      log: true,
      contract: 'DODOAdapter',
      args: [WETH, uniFactory]
    });

    const masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, ethers.provider.getSigner(deployer));

    const data = fs.readFileSync(POOL_JSON);
    const pools = JSON.parse(data);

    for (let pool of pools[POOL_ID].victimPools) {
      await masterVampire.add(DODOAdapter.address, pool.victimPID);
      if (pool.pid == undefined) {
        const pid = await masterVampire.poolLength() - 1;
        pool.pid = pid;
      }
    }

    pools[POOL_ID].deployedAdapter = DODOAdapter.address;

    fs.writeFileSync(POOL_JSON, JSON.stringify(pools, null, 2));
  }
};

export default func;
func.tags = ['dracula', 'live'];
