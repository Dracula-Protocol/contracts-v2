import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, WETH, treasury } = await getNamedAccounts();

  if (chainId != '1') {
    const weth = await deployments.get('WETH');
    WETH = weth.address;
  }

  const DrainController = await deployments.get('DrainController');
  const drainController = await ethers.getContractAt('DrainController', DrainController.address, ethers.provider.getSigner(deployer));

  const UniRewardPool = await deployments.get('UniRewardPool');
  const uniRewardPool = await ethers.getContractAt('RewardPool', UniRewardPool.address, ethers.provider.getSigner(deployer));
  const YFLRewardPool = await deployments.get('YFLRewardPool');
  const yflRewardPool = await ethers.getContractAt('RewardPool', YFLRewardPool.address, ethers.provider.getSigner(deployer));
  const DRCRewardPool = await deployments.get('DRCRewardPool');
  const drcRewardPool = await ethers.getContractAt('DRCRewardPool', DRCRewardPool.address, ethers.provider.getSigner(deployer));

  const DrainDistributor = await deploy('DrainDistributor', {
    from: deployer,
    log: true,
    contract: 'DrainDistributor',
    args: [WETH, treasury, uniRewardPool.address, yflRewardPool.address, drcRewardPool.address]
  });

  if (DrainDistributor.newlyDeployed) {
    const drainDistributor = await ethers.getContractAt('DrainDistributor', DrainDistributor.address, ethers.provider.getSigner(deployer));

    await drainDistributor.changeDrainController(drainController.address);

    await uniRewardPool.addRewardSupplier(drainDistributor.address);
    await yflRewardPool.addRewardSupplier(drainDistributor.address);
    await drcRewardPool.addRewardSupplier(drainDistributor.address);
  }
};

export default func;
func.tags = ['dracula', 'live'];
