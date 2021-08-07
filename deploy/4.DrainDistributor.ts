import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, WETH, DRC, treasury, sushiRouter } = await getNamedAccounts();

  /*if (chainId === '31337') {
    return;
  }*/

  if (chainId != '1') {
    const weth = await deployments.get('WETH');
    WETH = weth.address;
    const drc = await deployments.get('DRC');
    DRC = drc.address;
    const Router = await deployments.get('MockUniswapRouter');
    sushiRouter = Router.address;
  }

  const DrainController = await deployments.get('DrainController');
  const drainController = await ethers.getContractAt('DrainController', DrainController.address, ethers.provider.getSigner(deployer));

  const LPRewardPool = await deployments.get('LPRewardPool');
  const lpRewardPool = await ethers.getContractAt('RewardPool', LPRewardPool.address, ethers.provider.getSigner(deployer));
  const DraculaHoard = await deployments.get('DraculaHoard');
  const draculaHoard = await ethers.getContractAt('DraculaHoard', DraculaHoard.address, ethers.provider.getSigner(deployer));

  const DrainDistributor = await deploy('DrainDistributor', {
    from: deployer,
    log: true,
    contract: 'DrainDistributor',
    args: [WETH, DRC, treasury, lpRewardPool.address, draculaHoard.address, sushiRouter]
  });

  if (DrainDistributor.newlyDeployed) {
    const drainDistributor = await ethers.getContractAt('DrainDistributor', DrainDistributor.address, ethers.provider.getSigner(deployer));

    await drainDistributor.changeDrainController(drainController.address);

    await lpRewardPool.addRewardSupplier(drainDistributor.address);
  }
};

export default func;
func.tags = ['dracula', 'live'];
