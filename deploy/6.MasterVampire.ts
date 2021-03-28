import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  let { deployer } = await getNamedAccounts();

  const VampireAdapter = await deployments.get('VampireAdapter');
  const DrainController = await deployments.get('DrainController');
  const DrainDistributor = await deployments.get('DrainDistributor');
  const StrategyRari = await deployments.get('StrategyRari');
  const WETH = await deployments.get('WETH');

  const MasterVampire = await deploy('MasterVampire', {
    from: deployer,
    log: true,
    contract: 'MasterVampire',
    libraries: {
      VampireAdapter: VampireAdapter.address
    },
    args: [DrainDistributor.address, DrainController.address, StrategyRari.address, WETH.address]
  });
};

export default func;
func.tags = ['dracula', 'live'];
