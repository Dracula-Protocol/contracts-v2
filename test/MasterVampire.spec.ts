import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
const { waffle, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

import { advanceBlocks, advanceBlock, latestBlockTimestamp, advanceBlockAndTime, duration } from './utils';

import MockMasterChef from '../artifacts/contracts/test/MockMasterChef.sol/MockMasterChef.json';
import MockAdapter from '../artifacts/contracts/test/MockAdapter.sol/MockAdapter.json';
import ERC20Mock from '../artifacts/contracts/test/ERC20Mock.sol/ERC20Mock.json';

import IWETH from '../artifacts/contracts/interfaces/IWETH.sol/IWETH.json';
import DrainController from '../artifacts/contracts/DrainController.sol/DrainController.json';
import MasterVampire from '../artifacts/contracts/MasterVampire.sol/MasterVampire.json';
import DraculaToken from '../artifacts/contracts/DraculaToken.sol/DraculaToken.json';
import RewardPool from '../artifacts/contracts/RewardPool.sol/RewardPool.json';
import LiquidityController from '../artifacts/contracts/LiquidityController.sol/LiquidityController.json';
import DrainDistributor from '../artifacts/contracts/DrainDistributor.sol/DrainDistributor.json';
import VampireAdapter from '../artifacts/contracts/VampireAdapter.sol/VampireAdapter.json';

const loadFixture = waffle.createFixtureLoader(
  provider.getWallets(),
  provider
);

describe('MasterVampire', () => {

  const wallets = provider.getWallets();
  const [alice, bob, carol, dev, drain, drceth] = wallets;

  const TUSD = '0x0000000000085d4780B73119b644AE5ecd22b376';
  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
  const DRC = '0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8';

  const REWARD_DURATION = 604800; // 7 days

  async function fixture(allwallets:any) {
    const [alice, bob, carol, dev, drain, drceth] = allwallets;
    const VALib = await ethers.getContractFactory("VampireAdapter");
    const vampire_adapter = await VALib.deploy();
    await vampire_adapter.deployed();

    const MV = await ethers.getContractFactory("MasterVampire", {
      libraries: {
        VampireAdapter: vampire_adapter.address
      }
    });

    const DC = await ethers.getContractFactory("DrainController", {
      libraries: {
        VampireAdapter: vampire_adapter.address
      }
    });

    const weth = await ethers.getContractAt('IERC20', WETH);
    const drc = await ethers.getContractAt('IERC20', DRC);
    const lpcontroller = await deployContract(alice, LiquidityController);
    const rewardpool = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);

    const draindist = await deployContract(alice, DrainDistributor, [rewardpool.address, lpcontroller.address]);
    await draindist.changeDev(dev.address);
    await rewardpool.setRewardDistributor(draindist.address);

    const draincontroller = await DC.deploy(draindist.address);

    const master_vampire = await MV.deploy(drc.address, draindist.address, draincontroller.address);
    await master_vampire.updateRewardUpdaterAddress(alice.address);

    await draindist.changeDrainController(draincontroller.address);
    await draincontroller.setMasterVampire(master_vampire.address);

    const mock_token = await deployContract(alice, ERC20Mock, ['MockToken', 'MCK', alice.address, 0]);
    const lp = await deployContract(alice, ERC20Mock, ['LPToken', 'LP', alice.address, utils.parseEther('3000')]);
    await lp.transfer(bob.address, utils.parseEther('1000'));
    await lp.transfer(carol.address, utils.parseEther('1000'));

    // Create a MasterChef style mock that uses TUSD as rewards and a ERC20Mock as LP
    const tusd_token = await ethers.getContractAt('IERC20', TUSD);
    const master_mock = await deployContract(bob, MockMasterChef, [tusd_token.address, utils.parseEther('100'), '0', '0']);
    await master_mock.connect(bob).add('100', lp.address);

    // Since we cannot mint existing tokens on forked mainnet, we simulate it by swapping some ETH for TUSD and giving to MasterMock
    const uniswap_router = await ethers.getContractAt('IUniswapV2Router02', '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D');
    await weth.approve(uniswap_router.address, constants.MaxUint256);
    await uniswap_router.swapExactETHForTokens(0, [WETH, TUSD], master_mock.address, constants.MaxUint256, {
      value: utils.parseEther('100')
    });

    // Deploy the Mock Adapter and add the pools to MV
    const mock_adapter = await deployContract(alice, MockAdapter);
    await master_vampire.add(drceth.address, 0, 100, 0); // dummy DRC/ETH pool
    await master_vampire.add(mock_adapter.address, 0, 100, 0);

    // These need to be set in MockAdapter
    console.log("MasterVampire: ", master_vampire.address);
    console.log("MasterMock: ", master_mock.address);

    return {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter};
  }

  describe('setters & getters', () => {
    it('can set distribution period', async () => {
      const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
      await master_vampire.updateDistributionPeriod(666);
      expect(await master_vampire.distributionPeriod()).to.eq(666);
    });
    it('can set DRC/WETH reward share', async () => {
      const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
      await master_vampire.updateDrcWethRewardShare(33);
      expect(await master_vampire.drcWethShare()).to.eq(33);
    });
    it('can set dev address', async () => {
      const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
      await master_vampire.updateDevAddress(dev.address);
      expect(await master_vampire.devAddress()).to.eq(dev.address);
      await expect(
        master_vampire.updateDevAddress(carol.address)
      ).to.be.reverted;
      await master_vampire.connect(dev).updateDevAddress(carol.address);
      expect(await master_vampire.devAddress()).to.eq(carol.address);
    });
    it('can set drain address', async () => {
      const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
      await master_vampire.updateDrainAddress(drain.address);
      expect(await master_vampire.drainAddress()).to.eq(drain.address);
    });
    it('can set drain controller', async () => {
      const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
      await master_vampire.updateDrainController(bob.address);
      expect(await master_vampire.drainController()).to.eq(bob.address);
    });
    it('can set reward updater', async () => {
      const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
      await master_vampire.updateRewardUpdaterAddress(bob.address);
      expect(await master_vampire.poolRewardUpdater()).to.eq(bob.address);
    });
  });

  it('early withdrawal penalty works', async () => {
    const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);
    // Deposit the Mock LP into the Mock Adapter pool
    await lp.approve(master_vampire.address, utils.parseEther('1000'));
    await master_vampire.updateWithdrawPenalty('500'); // 50% penalty
    await master_vampire.deposit(1, utils.parseEther('1000'), 0);

    // Cool off time should be 24 hours after deposit
    const user_info = await master_vampire.userInfo(1, alice.address);
    let current_block_time = await latestBlockTimestamp();
    expect(user_info.coolOffTime).to.gte(current_block_time);
    expect(user_info.coolOffTime).to.gte(current_block_time.add(duration.hours(23)));

    await advanceBlocks(2);
    await draincontroller.whitelist(carol.address);
    await draincontroller.connect(carol).optimalMassDrain();

    // Withdrawing before cool off incurs penalty
    let pending_weth = await master_vampire.pendingWeth(1, alice.address);
    await master_vampire.withdraw(1, utils.parseEther('1000'), 0);
    expect(await weth.balanceOf(alice.address)).to.lt(pending_weth);

    // Withdrawing after cool off incurs NO penalty
    await lp.approve(master_vampire.address, utils.parseEther('1000'));
    await master_vampire.deposit(1, utils.parseEther('1000'), 0);
    await advanceBlocks(2);
    await advanceBlockAndTime(current_block_time.add(duration.hours(24)).toNumber());
    pending_weth = await master_vampire.pendingWeth(1, alice.address);
    await master_vampire.withdraw(1, utils.parseEther('1000'), 0);
    expect(await weth.balanceOf(alice.address)).to.gte(pending_weth);
  });

  it('mock adapter should work with mastervampire', async () => {
    const {weth, lp, drc, lpcontroller, rewardpool, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter} = await loadFixture(fixture);

    console.log("TUSD Balance (MasterMock): ", utils.formatEther((await tusd_token.balanceOf(master_mock.address))).toString());

    // Deposit the Mock LP into the Mock Adapter pool
    await lp.approve(master_vampire.address, utils.parseEther('1000'));
    await master_vampire.deposit(1, utils.parseEther('1000'), 0);

    // Advanced blocks
    await advanceBlocks(4);

    // Expect to have 400 TUSD (4 blocks/100 per block)
    expect((await master_mock.pendingMock(0, master_vampire.address)).valueOf()).to.eq(utils.parseEther('400'));
    console.log("Pending reward (alice): ", utils.formatEther((await master_mock.pendingMock(0, master_vampire.address)).toString()));

    console.log("Before Drain:");
    console.log("      WETH Balance (MasterVampire): ", (await weth.balanceOf(master_vampire.address)).toString());
    console.log("  WETH Balance (MockMasterVampire): ", (await weth.balanceOf(master_vampire.address)).toString());
    console.log("               ETH Balance (Carol):", utils.formatEther(await carol.getBalance()).toString());

    await draincontroller.whitelist(carol.address);
    await draincontroller.connect(carol).optimalMassDrain();

    console.log("After Drain:");
    console.log("  WETH Balance (MasterVampire): ", utils.formatEther(await weth.balanceOf(master_vampire.address)).toString());
    console.log("  WETH Balance (DrainDistributor): ", utils.formatEther(await weth.balanceOf(draindist.address)).toString());
    console.log("  WETH Balance (DrainController): ", utils.formatEther(await weth.balanceOf(draincontroller.address)).toString());
    console.log("  WETH Balance (Dev): ", utils.formatEther(await weth.balanceOf(dev.address)).toString());
    console.log("  WETH Balance (Pool): ", utils.formatEther(await weth.balanceOf(rewardpool.address)).toString());
    console.log("  ETH Balance (DrainController):", utils.formatEther(await provider.getBalance(draincontroller.address)).toString());
    console.log("  ETH Balance (Carol):", utils.formatEther(await carol.getBalance()).toString());

    console.log("  Pool (1) Acc WETH: ", utils.formatEther((await master_vampire.poolAccWeth(1)).toString()));
    for (let b = 0; b < 10; b++) {
      console.log("  Pending reward (alice): ", utils.formatEther((await master_vampire.pendingWeth(1, alice.address)).toString()));
      await advanceBlock();
    }
  });
});