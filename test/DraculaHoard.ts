import { expect } from 'chai'
import { Contract } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers } = require("hardhat");
const { deployContract } = waffle;

import { setupTestDracula } from './helpers/TestFixture';
import DraculaHoard from '../artifacts/contracts/DraculaHoard.sol/DraculaHoard.json';

describe('DraculaHoard', () => {
  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      carol:SignerWithAddress,
      drc:Contract,
      weth:Contract,
      stakingPool:Contract;

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    carol = await ethers.getSigner(config.carol);
    drc = config.drc;
    weth = config.weth;

    stakingPool = await deployContract(deployer, DraculaHoard, [drc.address]);
    await drc.mint(alice.address, '100');
    await drc.mint(bob.address, '100');
    await drc.mint(carol.address, '100');
  });

  it('Can burn correctly on unstake', async () => {
    await drc.connect(alice).approve(stakingPool.address, '100');
    // Alice enters and gets 100 shares.
    await stakingPool.connect(alice).stake('100');
    expect((await stakingPool.balanceOf(alice.address))).to.eq('100');
    expect((await drc.balanceOf(stakingPool.address))).to.eq('100');
    expect((await drc.balanceOf(alice.address))).to.eq('0');

    // Alice withdraws entire stake
    await stakingPool.connect(alice).unstake('100');

    expect((await stakingPool.balanceOf(alice.address))).to.eq('0');
    expect((await drc.balanceOf(stakingPool.address))).to.eq('0');
    expect((await drc.balanceOf(alice.address))).to.eq('99');
  });

  it('Can stake and unstake', async () => {
    await drc.connect(alice).approve(stakingPool.address, '100');
    await drc.connect(bob).approve(stakingPool.address, '100');
    // Alice enters and gets 20 shares. Bob enters and gets 10 shares.
    await stakingPool.connect(alice).stake('20');
    await stakingPool.connect(bob).stake('10');
    expect((await stakingPool.balanceOf(alice.address))).to.eq('20');
    expect((await stakingPool.balanceOf(bob.address))).to.eq('10');
    expect((await drc.balanceOf(stakingPool.address))).to.eq('30');
    // DraculaHoard get 20 more DRC from an external source.
    await drc.connect(carol).transfer(stakingPool.address, '20');
    // Alice deposits 10 more DRC. She should receive 10*30/50 = 6 shares.
    await stakingPool.connect(alice).stake('10');
    expect((await stakingPool.balanceOf(alice.address))).to.eq('26');
    expect((await stakingPool.balanceOf(bob.address))).to.eq('10');
    // Bob withdraws 5 shares. He should receive 5*60/36 = 8 shares
    await stakingPool.connect(bob).unstake('5');
    expect((await stakingPool.balanceOf(alice.address))).to.eq('26');
    expect((await stakingPool.balanceOf(bob.address))).to.eq('5');
    expect((await drc.balanceOf(stakingPool.address))).to.eq('52');
    expect((await drc.balanceOf(alice.address))).to.eq('70');
    expect((await drc.balanceOf(bob.address))).to.eq('98');
  });
});
