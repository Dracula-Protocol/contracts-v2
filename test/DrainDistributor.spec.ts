import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
const { waffle, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

const loadFixture = waffle.createFixtureLoader(
  provider.getWallets(),
  provider
);

import { advanceBlockTo, latestBlockTimestamp } from './utils';

import DrainDistributor from '../artifacts/contracts/DrainDistributor.sol/DrainDistributor.json';
import RewardPool from '../artifacts/contracts/RewardPool.sol/RewardPool.json';

describe('DrainDistributor', () => {
  const wallets = provider.getWallets();
  const [alice, bob, carol, dev, node] = wallets;

  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
  const DRC = '0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8';
  const REWARD_DURATION = 604800; // 7 days

  async function fixture(allwallets:any) {
    const [alice, bob, carol, dev] = allwallets;

    const weth = await ethers.getContractAt('IWETH', WETH);
    const drc = await ethers.getContractAt('IERC20', DRC);
    const rewardpool1 = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);
    const rewardpool2 = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);
    const rewardpool3 = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);

    const drain_distributor = await deployContract(alice, DrainDistributor, [rewardpool1.address, rewardpool2.address, rewardpool3.address]);
    await drain_distributor.changeDev(dev.address);
    await rewardpool1.addRewardSupplier(drain_distributor.address);
    await rewardpool2.addRewardSupplier(drain_distributor.address);
    await rewardpool3.addRewardSupplier(drain_distributor.address);

    return {weth, rewardpool1, rewardpool2, rewardpool3, drain_distributor};
  }

  describe('setters & getters', () => {
    it('can set dev', async () => {
      const {weth, rewardpool1, rewardpool2, rewardpool3, drain_distributor} = await loadFixture(fixture);
      await drain_distributor.changeDev(carol.address);
      expect(await drain_distributor.devFund()).to.eq(carol.address);
    });
    it('can set reward pools', async () => {
      const {weth, rewardpool1, rewardpool2, rewardpool3, drain_distributor} = await loadFixture(fixture);
      expect(await drain_distributor.uniRewardPool()).to.not.eq(bob.address);
      await drain_distributor.changeUniRewardPool(bob.address);
      expect(await drain_distributor.uniRewardPool()).to.eq(bob.address);
      expect(await drain_distributor.yflRewardPool()).to.not.eq(carol.address);
      await drain_distributor.changeYFLRewardPool(carol.address);
      expect(await drain_distributor.yflRewardPool()).to.eq(carol.address);
      expect(await drain_distributor.drcRewardPool()).to.not.eq(alice.address);
      await drain_distributor.changeDRCRewardPool(alice.address);
      expect(await drain_distributor.drcRewardPool()).to.eq(alice.address);
    });
    it('can set drain controller', async () => {
      const {weth, rewardpool1, rewardpool2, rewardpool3, drain_distributor} = await loadFixture(fixture);
      await drain_distributor.changeDrainController(node.address);
      expect(await drain_distributor.drainController()).to.eq(node.address);
    });
    it('can set distribution', async () => {
      const {weth, rewardpool1, rewardpool2, rewardpool3, drain_distributor} = await loadFixture(fixture);
      expect(await drain_distributor.gasShare()).to.eq(100);
      expect(await drain_distributor.devShare()).to.eq(200);
      expect(await drain_distributor.uniRewardPoolShare()).to.eq(200);
      expect(await drain_distributor.yflRewardPoolShare()).to.eq(200);
      expect(await drain_distributor.drcRewardPoolShare()).to.eq(300);
      await drain_distributor.changeDistribution(200, 200, 200, 200, 200);
      expect(await drain_distributor.gasShare()).to.eq(200);
      expect(await drain_distributor.devShare()).to.eq(200);
      expect(await drain_distributor.uniRewardPoolShare()).to.eq(200);
      expect(await drain_distributor.yflRewardPoolShare()).to.eq(200);
      expect(await drain_distributor.drcRewardPoolShare()).to.eq(200);
      await expect(
        drain_distributor.changeDistribution(200, 100, 300, 300, 200)
      ).to.be.reverted;
    });
  });

  describe('distribute', () => {
    it('can distribute rewards', async () => {
      const {weth, rewardpool1, rewardpool2, rewardpool3, drain_distributor} = await loadFixture(fixture);
      await drain_distributor.changeDev(dev.address);
      await drain_distributor.changeDrainController(carol.address);

      await weth.deposit({value : utils.parseEther('5')});
      await weth.transfer(drain_distributor.address, utils.parseEther('1'));

      expect(await weth.balanceOf(drain_distributor.address)).to.eq(utils.parseEther('1'));
      await drain_distributor.distribute();
      expect(await carol.getBalance()).to.eq(utils.parseEther('10000.1'));
      expect(await weth.balanceOf(dev.address)).to.eq(utils.parseEther('0.2'));
      expect(await weth.balanceOf(rewardpool1.address)).to.eq(utils.parseEther('0.2'));
      expect(await weth.balanceOf(rewardpool2.address)).to.eq(utils.parseEther('0.2'));
      expect(await weth.balanceOf(rewardpool3.address)).to.eq(utils.parseEther('0.3'));

      await weth.transfer(drain_distributor.address, utils.parseEther('1'));
      await drain_distributor.distribute();
      expect(await carol.getBalance()).to.eq(utils.parseEther('10000.2'));
      expect(await weth.balanceOf(dev.address)).to.eq(utils.parseEther('0.4'));
      expect(await weth.balanceOf(rewardpool1.address)).to.eq(utils.parseEther('0.4'));
      expect(await weth.balanceOf(rewardpool2.address)).to.eq(utils.parseEther('0.4'));
      expect(await weth.balanceOf(rewardpool3.address)).to.eq(utils.parseEther('0.6'));
    });
  });
});