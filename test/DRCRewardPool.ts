import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");
const { deployContract } = waffle;

import { setupTestDracula } from './helpers/TestFixture';
import { advanceBlockAndTime } from './helpers/Utils';

import DRCRewardPool from '../artifacts/contracts/DRCRewardPool.sol/DRCRewardPool.json';

describe('DRCRewardPool', () => {
  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      drc:Contract,
      weth:Contract,
      rewardPool:Contract;

  const DURATION = 604800; // 7 days

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    drc = config.drc;
    weth = config.weth;

    rewardPool = await deployContract(deployer, DRCRewardPool, [weth.address, drc.address, DURATION, deployer.address]);
  });

  it('Can stake and withdraw', async () => {
    await drc.mint(alice.address, utils.parseEther('1000'));
    await drc.connect(alice).approve(rewardPool.address, constants.MaxUint256);

    await rewardPool.connect(alice).stake(utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(0);
    expect(await rewardPool.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));

    await rewardPool.connect(alice).unstake(utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('990')); // 1000 - 1% burn fee
    expect(await rewardPool.balanceOf(alice.address)).to.eq(0);
  });

  it('Can set burn rate', async () => {
    await rewardPool.setBurnRate(5);
    expect(await rewardPool.burnRate()).to.eq(5);
    await expect(
        rewardPool.burnRate(50)
    ).to.be.reverted;
  });
});
