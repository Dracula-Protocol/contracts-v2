import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, DRC, WETH, uniFactory, rariFundManager } = await getNamedAccounts();

  if (chainId != '1') {
    const drc = await deployments.get('DRC');
    DRC = drc.address;
    const weth = await deployments.get('WETH');
    WETH = weth.address;
    const factory = await deployments.get('MockUniswapFactory');
    uniFactory = factory.address;

    const RariFundManager = await deploy('MockRariFundManager', {
      from: deployer,
      log: true,
      contract: 'MockRariFundManager'
    });

    rariFundManager = RariFundManager.address;
  }

  await deploy('StrategyRari', {
    from: deployer,
    log: true,
    contract: 'IBVEthRari',
    args: [DRC, WETH, uniFactory, rariFundManager]
  });

};

export default func;
func.tags = ['disabled'];
