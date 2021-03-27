import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;
  const chainId = await getChainId();

  let { deployer, WETH, uniRouter } = await getNamedAccounts();

  if (chainId != '1') {
    const MasterVampire = await deployments.get('MasterVampire');
    const MockMasterChefToken = await deployments.get('MockMasterChefToken');
    const MockMasterChef = await deployments.get('MockMasterChef');
    const weth = await deployments.get('WETH');
    WETH = weth.address;
    const Router = await deployments.get('MockUniswapRouter');
    uniRouter = Router.address;
    const MockUniswapFactory = await deployments.get('MockUniswapFactory');

    const MockChefLP = await deploy('MockChefLP', {
      from: deployer,
      log: true,
      contract: 'MockERC20',
      args: ['Chef LP', 'CLP', 18]
    });

    const MockChefAdapter = await deploy('MockChefAdapter', {
      from: deployer,
      log: true,
      contract: 'MockAdapter',
      args: [MasterVampire.address, MockMasterChef.address, MockMasterChefToken.address, WETH, uniRouter, MockUniswapFactory.address]
    });

    const mockMasterChef = await ethers.getContractAt('MockMasterChef', MockMasterChef.address, ethers.provider.getSigner(deployer));
    await mockMasterChef.add('100', MockChefLP.address);

    const masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, ethers.provider.getSigner(deployer));
    await masterVampire.add(MockChefAdapter.address, 0);
  }
};

export default func;
func.tags = ['dracula'];
