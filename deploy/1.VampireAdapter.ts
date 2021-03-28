import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  let { deployer } = await getNamedAccounts();

  await deploy('VampireAdapter', {
    from: deployer,
    log: true,
    contract: 'VampireAdapter',
  });
};

export default func;
func.tags = ['dracula', 'live'];
