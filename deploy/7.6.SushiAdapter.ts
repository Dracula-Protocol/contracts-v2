import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
const fs = require('fs');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();
  const POOL_JSON = __dirname + '/data/pools.json';
  const POOL_ID = 'sushi';

  let { deployer, WETH, sushiFactory } = await getNamedAccounts();

  if (chainId === '31337') {
    return;
  }

  if (chainId == '1') {
    const MasterVampire = await deployments.get('MasterVampire');
    const masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, ethers.provider.getSigner(deployer));

    const SushiAdapter = await deploy('SushiAdapter', {
      from: deployer,
      log: true,
      contract: 'SushiAdapter',
      args: [WETH, sushiFactory, masterVampire.address]
    });

    if (SushiAdapter.newlyDeployed) {
      const data = fs.readFileSync(POOL_JSON);
      const pools = JSON.parse(data);

      pools[POOL_ID].deployedAdapter = SushiAdapter.address;

      if (!pools[POOL_ID].deployedAdapter || pools[POOL_ID].deployedAdapter.length === 0) {
        let nextPID = (await masterVampire.poolLength()).toNumber();
        for (let pool of pools[POOL_ID].victimPools) {
          await masterVampire.add(SushiAdapter.address, pool.victimPID);
          if (pool.pid == undefined) {
            pool.pid = nextPID;
            nextPID++;
          }
        }
      } else {
        console.log("Updating SUSHI adapter to:", SushiAdapter.address)

        for (let pool of pools[POOL_ID].victimPools) {
          await masterVampire.updateVictimAddress(pool.pid, SushiAdapter.address);
        }
      }

      fs.writeFileSync(POOL_JSON, JSON.stringify(pools, null, 2));
    }
  }
};

export default func;
func.tags = ['dracula', 'live'];
