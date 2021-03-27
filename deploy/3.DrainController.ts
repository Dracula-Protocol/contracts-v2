import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, chi } = await getNamedAccounts();

  if (chainId != '1') {
    const CHI = await deployments.get('MockChiToken');
    chi = CHI.address;
  }

  const VampireAdapter = await deployments.get('VampireAdapter');

  const DrainController = await deploy('DrainController', {
    from: deployer,
    log: true,
    contract: 'DrainController',
    libraries: {
      VampireAdapter: VampireAdapter.address
    },
    args: [chi]
  });
};

export default func;
func.tags = ['dracula', 'live'];
