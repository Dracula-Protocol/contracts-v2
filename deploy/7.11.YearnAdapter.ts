import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import { VictimPoolInfo } from "./data/types";
const fs = require('fs');

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();
  const POOL_JSON = __dirname + '/data/pools.json';
  const POOL_ID = 'yearn';

  let { deployer, WETH, sushiFactory } = await getNamedAccounts();

  if (chainId === '31337') {
    return;
  }

  if (chainId == '1') {
    const MasterVampire = await deployments.get('MasterVampire');
    const masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, ethers.provider.getSigner(deployer));

    const data = fs.readFileSync(POOL_JSON);
    const pools = JSON.parse(data);

    const victimLPs:string[] = pools[POOL_ID].victimPools.map((p:VictimPoolInfo) => p.lp);

    console.log("Yearn Vaults:", victimLPs)

    const YearnV2Adapter = await deploy('YearnV2Adapter', {
      from: deployer,
      log: true,
      contract: 'YearnV2Adapter',
      args: [WETH, sushiFactory, masterVampire.address, victimLPs]
    });

    if (YearnV2Adapter.newlyDeployed) {
      let nextPID = (await masterVampire.poolLength()).toNumber();
      const currentVictimPools:VictimPoolInfo[] = pools[POOL_ID].victimPools.filter((p:VictimPoolInfo) => p.pid !== undefined);
      const pendingVictimPools:VictimPoolInfo[] = pools[POOL_ID].victimPools.filter((p:VictimPoolInfo) => p.pid === undefined);

      for (let pool of pendingVictimPools) {
        if (pool.pid === undefined) {
          pool.pid = nextPID;
          nextPID++;
        }
      }

      const newVictimPIDs:number[] = pendingVictimPools.map((p:VictimPoolInfo) => {
        return p.victimPID;
      });

      await masterVampire.addBulk(YearnV2Adapter.address, newVictimPIDs);

      pools[POOL_ID].victimPools = currentVictimPools.concat(pendingVictimPools);
      pools[POOL_ID].deployedAdapter = YearnV2Adapter.address;

      fs.writeFileSync(POOL_JSON, JSON.stringify(pools, null, 2));
    }
  }
};

export default func;
func.tags = ['dracula', 'live'];
