import {ethers, deployments} from 'hardhat';

const setupTest = deployments.createFixture(async ({deployments, getNamedAccounts, ethers}, options) => {
  await deployments.fixture('dracula');
  let {
    deployer,
    alice,
    bob,
    carol,
    tom,
    treasury
  } = await getNamedAccounts();

  const DRC = await deployments.get('DRC');
  const drc = await ethers.getContractAt('MockERC20', DRC.address, ethers.provider.getSigner(deployer));
  const DAI = await deployments.get('DAI');
  const dai = await ethers.getContractAt('MockERC20', DAI.address, ethers.provider.getSigner(deployer));
  const USDC = await deployments.get('USDC');
  const usdc = await ethers.getContractAt('MockERC20', USDC.address, ethers.provider.getSigner(deployer));

  const WETH = await deployments.get('WETH');
  const weth = await ethers.getContractAt('MockWETH', WETH.address, ethers.provider.getSigner(deployer));
  const Router = await deployments.get('MockUniswapRouter');
  const router = await ethers.getContractAt(
      'MockUniswapRouter',
      Router.address,
      ethers.provider.getSigner(deployer)
  );

  await dai.faucet(ethers.utils.parseEther('1000'));
  await usdc.faucet('1000000000');

  return {
      deployer,
      alice,
      bob,
      carol,
      tom,
      treasury,
      drc,
      dai,
      usdc,
      weth,
      router
  };
});

export { setupTest as setupTestDracula }
