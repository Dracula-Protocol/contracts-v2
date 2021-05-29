import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { utils } from "ethers";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy, execute } = deployments;

  const { deployer, treasury } = await getNamedAccounts();
  const chainId = await getChainId();

  if (chainId != '1') {
    const DRC = await deploy('DRC', {
      from: deployer,
      log: true,
      contract: 'MockERC20',
      args: ['Dracula', 'DRC', 18]
    });

    await deploy('DAI', {
      from: deployer,
      log: true,
      contract: 'MockERC20',
      args: ['Dai Stablecoin', 'DAI', 18]
    });

    await deploy('USDC', {
      from: deployer,
      log: true,
      contract: 'MockERC20',
      args: ['USD Coin', 'USDC', 6]
    });

    const WETH = await deploy('WETH', {
      from: deployer,
      log: true,
      contract: 'MockWETH'
    });

    await deploy('DRCETHSLP', {
      from: deployer,
      log: true,
      contract: 'MockERC20',
      args: ['DRC-ETH SLP', 'SLP', 18]
    });

    await deploy('MockChiToken', {
      from: deployer,
      log: true,
      contract: 'MockChiToken'
    });

    const MockMasterChefToken = await deploy('MockMasterChefToken', {
      from: deployer,
      log: true,
      contract: 'MockERC20',
      args: ['Chef Token', 'CT', 18]
    });

    await deploy('MockMasterChef', {
      from: deployer,
      log: true,
      contract: 'MockMasterChef',
      args: [MockMasterChefToken.address, utils.parseEther('0.01'), 0, 0]
    });

    const mockMasterChef = await deployments.get('MockMasterChef');

    const MockUniswapFactory = await deploy('MockUniswapFactory', {
      from: deployer,
      log: true,
      args: [treasury]
    });

    const UniRouter = await deploy('MockArcherSwapRouter', {
      from: deployer,
      log: true,
      args: [MockUniswapFactory.address]
    });

    await execute(
      'MockMasterChefToken',
      { from: deployer },
      'mint',
      UniRouter.address,
      utils.parseEther('5000')
    );

    // Get some WETH from ETH
    await execute(
      'WETH',
      { from: deployer, value: utils.parseEther('1500') },
      'deposit'
    );

    await execute(
      'WETH',
      { from: deployer },
      'transfer',
      UniRouter.address,
      utils.parseEther('5')
    );

    // Add ChefToken liquidity
    await execute(
      'MockMasterChefToken',
      { from: deployer },
      'mint',
      deployer,
      utils.parseEther('1000')
    );

    await execute(
      'MockMasterChefToken',
      { from: deployer },
      'approve',
      UniRouter.address,
      utils.parseEther('1000')
    );
    await execute(
      'WETH',
      { from: deployer },
      'approve',
      UniRouter.address,
      utils.parseEther('1000')
    );

    await execute(
      'MockArcherSwapRouter',
      { from: deployer },
      'addLiquidity',
      WETH.address,
      MockMasterChefToken.address,
      utils.parseEther('1000'),
      utils.parseEther('400'),
      0,
      0,
      deployer,
      0
    );


    // Add DRC/WETH liquidity
    await execute(
      'DRC',
      { from: deployer },
      'mint',
      deployer,
      utils.parseEther('5000')
    );

    await execute(
      'DRC',
      { from: deployer },
      'approve',
      UniRouter.address,
      utils.parseEther('1000')
    );
    await execute(
      'WETH',
      { from: deployer },
      'approve',
      UniRouter.address,
      utils.parseEther('50')
    );

    await execute(
      'MockArcherSwapRouter',
      { from: deployer },
      'addLiquidity',
      WETH.address,
      DRC.address,
      utils.parseEther('50'),
      utils.parseEther('500'),
      0,
      0,
      deployer,
      0
    );


    await execute(
      'MockMasterChefToken',
      { from: deployer },
      'transferOwnership',
      mockMasterChef.address
    );
  }
};

export default func;
func.tags = ['dracula'];
