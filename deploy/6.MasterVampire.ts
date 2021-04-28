import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, WETH } = await getNamedAccounts();

  if (chainId != '1') {
    const weth = await deployments.get('WETH');
    WETH = weth.address;
  }

  const VampireAdapter = await deployments.get('VampireAdapter');
  const DrainController = await deployments.get('DrainController');
  const DrainDistributor = await deployments.get('DrainDistributor');
  const StrategyRari = await deployments.get('StrategyRari');

  const MasterVampire = await deploy('MasterVampire', {
    from: deployer,
    log: true,
    contract: 'MasterVampire',
    libraries: {
      VampireAdapter: VampireAdapter.address
    },
    args: [DrainDistributor.address, DrainController.address, StrategyRari.address, WETH]
  });

  if (MasterVampire.newlyDeployed) {
    const drainController = await ethers.getContractAt('DrainController', DrainController.address, ethers.provider.getSigner(deployer));
    await drainController.setMasterVampire(MasterVampire.address);
  }
};

export default func;
func.tags = ['disabled'];
