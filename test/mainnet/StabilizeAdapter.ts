import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");
const { deployContract } = waffle;

import { setupTestDracula } from '../helpers/TestFixture';

import StabilizeAdapter from '../../artifacts/contracts/adapters/stabilize/StabilizeAdapter.sol/StabilizeAdapter.json';

describe('StabilizeAdapter', () => {
  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      masterVampire:string,
      uniFactory:string,
      uniRouter:string,
      WETH:string,
      stabilizeAdapter:Contract;

  const STBZ = '0xB987D48Ed8f2C468D52D6405624EADBa5e76d723';

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    masterVampire = '0xF8CD76Cb1bcD0c369DE896Acb592d92Cd823cA03';
    uniFactory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
    uniRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

    stabilizeAdapter = await deployContract(deployer, StabilizeAdapter, [WETH, uniFactory, masterVampire]);
  });

  it('can sell reward for weth', async () => {
    const weth = await ethers.getContractAt('IERC20', WETH);
    const stbz = await ethers.getContractAt('IERC20', STBZ);

    expect(await stbz.balanceOf(alice.address)).to.eq(0);
    expect(await stbz.balanceOf(stabilizeAdapter.address)).to.eq(0);
    expect(await weth.balanceOf(bob.address)).to.eq(0);

    const uniswap_router = await ethers.getContractAt('IUniswapV2Router02', uniRouter);
    await weth.approve(uniswap_router.address, constants.MaxUint256);
    await uniswap_router.swapExactETHForTokens(0, [WETH, STBZ], stabilizeAdapter.address, constants.MaxUint256, {
      value: utils.parseEther('1')
    });

    expect(await stbz.balanceOf(stabilizeAdapter.address)).to.gt(0);
    const stbz_balance = await stbz.balanceOf(stabilizeAdapter.address);
    await stabilizeAdapter.sellRewardForWeth(stabilizeAdapter.address, 0, stbz_balance, bob.address);
    expect(await weth.balanceOf(bob.address)).to.gt(utils.parseEther('0.9'));
    expect(await stbz.balanceOf(stabilizeAdapter.address)).to.eq(0);
  });
});