import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, DRC, WETH, sushiFactory, yvWETHVault } = await getNamedAccounts();

  /*if (chainId === '31337') {
    return;
  }*/

  if (chainId != '1') {
    const drc = await deployments.get('DRC');
    DRC = drc.address;
    const weth = await deployments.get('WETH');
    WETH = weth.address;
    const factory = await deployments.get('MockUniswapFactory');
    sushiFactory = factory.address;

    const MockYearnV2 = await deploy('MockYearnV2', {
      from: deployer,
      log: true,
      contract: 'MockYearnV2',
      args: ["WETH yVault ", "yvWETH", WETH]
    });

    yvWETHVault = MockYearnV2.address;
  }

  await deploy('StrategyYearn', {
    from: deployer,
    log: true,
    contract: 'YearnV2WETH',
    args: [DRC, WETH, sushiFactory, yvWETHVault]
  });

};

export default func;
func.tags = ['dracula'];
