import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, alice, DRC, WETH, DRCETHUNI, DRCETHYFL } = await getNamedAccounts();

  if (chainId != '1') {
    const drc = await deployments.get('DRC');
    DRC = drc.address;
    const weth = await deployments.get('WETH');
    WETH = weth.address;
    const drcethuni = await deployments.get('DRCETHUNI');
    DRCETHUNI = drcethuni.address;
    const drcethyfl = await deployments.get('DRCETHYFL');
    DRCETHYFL = drcethyfl.address;
  }

  const REWARD_DISTRIBUTION_DURATION_DAYS_IN_BLOCKS = 172800; // 2 days
  await deploy('UniRewardPool', {
    from: deployer,
    log: true,
    contract: 'RewardPool',
    args: [WETH, DRCETHUNI, REWARD_DISTRIBUTION_DURATION_DAYS_IN_BLOCKS, deployer]
  });

  await deploy('YFLRewardPool', {
    from: deployer,
    log: true,
    contract: 'RewardPool',
    args: [WETH, DRCETHYFL, REWARD_DISTRIBUTION_DURATION_DAYS_IN_BLOCKS, deployer]
  });

  await deploy('DRCRewardPool', {
    from: deployer,
    log: true,
    contract: 'DRCRewardPool',
    args: [WETH, DRC, REWARD_DISTRIBUTION_DURATION_DAYS_IN_BLOCKS, deployer]
  });
};

export default func;
func.tags = ['dracula', 'live'];
