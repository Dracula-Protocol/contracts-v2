import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");
const { deployContract } = waffle;

import { setupTestDracula } from './helpers/TestFixture';

import SushiAdapter from '../artifacts/contracts/adapters/sushi/SushiAdapter.sol/SushiAdapter.json';

describe('SushiAdapter', () => {
  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      masterVampire:string,
      uniFactory:string,
      uniRouter:string,
      WETH:string,
      sushiAdapter:Contract;

  const SUSHI = '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2';

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    masterVampire = '0xF8CD76Cb1bcD0c369DE896Acb592d92Cd823cA03';
    uniFactory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
    uniRouter = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

    sushiAdapter = await deployContract(deployer, SushiAdapter, [WETH, uniFactory, masterVampire]);
  });

  it('can sell reward for weth', async () => {
    const weth = await ethers.getContractAt('IERC20', WETH);
    const sushi = await ethers.getContractAt('IERC20', SUSHI);

    expect(await sushi.balanceOf(alice.address)).to.eq(0);
    expect(await sushi.balanceOf(sushiAdapter.address)).to.eq(0);
    expect(await weth.balanceOf(bob.address)).to.eq(0);

    const uniswap_router = await ethers.getContractAt('IUniswapV2Router02', uniRouter);
    await weth.approve(uniswap_router.address, constants.MaxUint256);
    await uniswap_router.swapExactETHForTokens(0, [WETH, SUSHI], sushiAdapter.address, constants.MaxUint256, {
      value: utils.parseEther('1')
    });

    expect(await sushi.balanceOf(sushiAdapter.address)).to.gt(0);
    const sushi_balance = await sushi.balanceOf(sushiAdapter.address);
    await sushiAdapter.sellRewardForWeth(sushiAdapter.address, 0, sushi_balance, bob.address);
    expect(await weth.balanceOf(bob.address)).to.gt(utils.parseEther('0.9'));
    expect(await sushi.balanceOf(sushiAdapter.address)).to.eq(0);
  });
});