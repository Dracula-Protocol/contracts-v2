import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");
const { deployContract } = waffle;

import { setupTestDracula } from './helpers/TestFixture';
import { advanceBlockAndTime } from './helpers/Utils';

import RewardPool from '../artifacts/contracts/RewardPool.sol/RewardPool.json';

describe('RewardPool', () => {
  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      drc:Contract,
      weth:Contract,
      rewardPool:Contract;

  const DURATION = 604800; // 7 days

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    drc = config.drc;
    weth = config.weth;

    await weth.deposit({value: utils.parseEther('500')});

    rewardPool = await deployContract(deployer, RewardPool, [weth.address, drc.address, DURATION, deployer.address]);
    await weth.approve(rewardPool.address, constants.MaxUint256);
  });

  it('Can stake and withdraw', async () => {
    await drc.mint(alice.address, utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));

    await drc.connect(alice).approve(rewardPool.address, constants.MaxUint256);
    await rewardPool.connect(alice).stake(utils.parseEther('1000'));

    expect(await drc.balanceOf(alice.address)).to.eq(0);
    expect(await rewardPool.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));

    await rewardPool.connect(alice).unstake(utils.parseEther('1000'));

    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));
    expect(await rewardPool.balanceOf(alice.address)).to.eq(0);
  });

  it('Can unstake', async () => {
    await drc.mint(alice.address, utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));
    await drc.connect(alice).approve(rewardPool.address, constants.MaxUint256);
    await rewardPool.connect(alice).stake(utils.parseEther('1000'));
    expect(await rewardPool.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));

    // Fund the Reward Pool
    await rewardPool.fundPool(utils.parseEther('100'));

    await advanceBlockAndTime(DURATION);

    expect(await rewardPool.earned(alice.address)).to.gte(utils.parseEther('99'));

    await rewardPool.connect(alice).unstake(utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));
  });

  it('Can withdraw', async () => {
    await drc.mint(alice.address, utils.parseEther('100'));

    const DURATION = 7200; // 2 hours

    await drc.connect(alice).approve(rewardPool.address, constants.MaxUint256);
    await rewardPool.connect(alice).stake(utils.parseEther('50'));
    expect(await rewardPool.userRewardPerTokenPaid(alice.address)).to.eq(0);

    await rewardPool.fundPool(utils.parseEther('100'));

    await rewardPool.connect(alice).stake(utils.parseEther('20'));
    await advanceBlockAndTime(DURATION*0.5);

    await rewardPool.fundPool(utils.parseEther('100'));

    await rewardPool.connect(alice).stake(utils.parseEther('30'));
    await advanceBlockAndTime(DURATION*2.5);

    expect(await await rewardPool.totalStaked()).to.eq(utils.parseEther('100'));
    expect(await rewardPool.earned(alice.address)).to.gte(utils.parseEther('199'));
    expect(await drc.balanceOf(alice.address)).to.eq(0);

    await rewardPool.connect(alice).unstake(utils.parseEther('100'));

    expect(await await rewardPool.totalStaked()).to.eq(0);
    expect(await rewardPool.earned(alice.address)).to.eq(0);
    expect(await weth.balanceOf(alice.address)).to.gte(utils.parseEther('199'));
    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('100'));
  });

  it('Can earn rewards', async () => {
    await drc.mint(alice.address, utils.parseEther('100'));
    await drc.mint(bob.address, utils.parseEther('100'));

    // User 0 stake
    await drc.connect(alice).approve(rewardPool.address, constants.MaxUint256);
    await rewardPool.connect(alice).stake(utils.parseEther('100'));

    // Fund the rewardPool
    await rewardPool.fundPool(utils.parseEther('200'));

    // User 1 stake
    await drc.connect(bob).approve(rewardPool.address, constants.MaxUint256);
    await rewardPool.connect(bob).stake(utils.parseEther('100'));

    await advanceBlockAndTime(DURATION/2);

    // Users will have half the weekly reward shared
    expect(await rewardPool.earned(alice.address)).to.gte(utils.parseEther('49'));
    expect(await rewardPool.earned(bob.address)).to.gte(utils.parseEther('49'));

    await advanceBlockAndTime(DURATION/2);

    // Users will have the entire weekly reward shared
    expect(await rewardPool.earned(alice.address)).to.gte(utils.parseEther('99'));
    expect(await rewardPool.earned(bob.address)).to.gte(utils.parseEther('99'));
  });
});