import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, execute } = deployments;
  const chainId = await getChainId();

  let { deployer } = await getNamedAccounts();

  if (chainId === '31337') {
    return;
  }

  const DELAY = 60 * 60 * 6; // initially 6 hours until deployment is all complete

  const Timelock = await deploy('Timelock', {
    from: deployer,
    log: true,
    contract: 'Timelock',
    args: [deployer, DELAY]
  });

  // Might not want to transfer ownership right at deployment time until testing is done
  /*if (chainId == '1') {
    await execute(
      'MasterVampire',
      { from: deployer },
      'transferOwnership',
      Timelock.address
    );
  }*/
};

export default func;
func.tags = ['dracula', 'live'];
