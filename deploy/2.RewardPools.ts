import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, DRC, WETH, DRCETHSLP } = await getNamedAccounts();

  /*if (chainId === '31337') {
    return;
  }*/

  if (chainId != '1') {
    const drc = await deployments.get('DRC');
    DRC = drc.address;
    const weth = await deployments.get('WETH');
    WETH = weth.address;
    const drcethslp = await deployments.get('DRCETHSLP');
    DRCETHSLP = drcethslp.address;
  }

  const REWARD_DISTRIBUTION_DURATION_DAYS_SECS = 172800; // 2 days
  await deploy('LPRewardPool', {
    from: deployer,
    log: true,
    contract: 'RewardPool',
    args: [WETH, DRCETHSLP, REWARD_DISTRIBUTION_DURATION_DAYS_SECS, deployer]
  });

  await deploy('DraculaHoard', {
    from: deployer,
    log: true,
    contract: 'DraculaHoard',
    args: [DRC]
  });
};

export default func;
func.tags = ['dracula', 'live'];
