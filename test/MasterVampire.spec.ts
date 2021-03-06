import { expect } from 'chai'
import { Contract, constants, utils, BigNumber } from 'ethers'
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
import DrainDistributor from '../artifacts/contracts/DrainDistributor.sol/DrainDistributor.json';
import VampireAdapter from '../artifacts/contracts/VampireAdapter.sol/VampireAdapter.json';
import IIBVEth from '../artifacts/contracts/IIBVEth.sol/IIBVEth.json';
import IBVEthRari from '../artifacts/contracts/strategies/IBVEthRari.sol/IBVEthRari.json';

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
  const IBETH = '0xeEa3311250FE4c3268F8E684f7C87A82fF183Ec1';
  const REPT = '0xCda4770d65B4211364Cb870aD6bE19E7Ef1D65f4';
  const UNI_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

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
    const rewardpool1 = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);
    const rewardpool2 = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);
    const rewardpool3 = await deployContract(alice, RewardPool, [weth.address, drc.address, REWARD_DURATION, alice.address]);

    const draindist = await deployContract(alice, DrainDistributor, [rewardpool1.address, rewardpool2.address, rewardpool3.address]);
    await draindist.changeDev(dev.address);
    await rewardpool1.addRewardSupplier(draindist.address);
    await rewardpool2.addRewardSupplier(draindist.address);
    await rewardpool3.addRewardSupplier(draindist.address);

    const draincontroller = await DC.deploy();

    const ibveth = await deployContract(alice, IBVEthRari, [DRC]);
    const master_vampire = await MV.deploy(draindist.address, draincontroller.address, ibveth.address);
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
    const uniswap_router = await ethers.getContractAt('IUniswapV2Router02', UNI_ROUTER);
    await weth.approve(uniswap_router.address, constants.MaxUint256);
    await uniswap_router.swapExactETHForTokens(0, [WETH, TUSD], master_mock.address, constants.MaxUint256, {
      value: utils.parseEther('100')
    });

    // Deploy the Mock Adapter and add the pools to MV
    const mock_adapter = await deployContract(alice, MockAdapter, [master_vampire.address, master_mock.address]);
    await master_vampire.add(mock_adapter.address, 0, 0);

    return {weth, lp, drc, rewardpool1, rewardpool2, rewardpool3, draindist, master_vampire, draincontroller, mock_token, tusd_token, master_mock, mock_adapter};
  }

  describe('setters & getters', () => {
    it('can set distribution period', async () => {
      const {master_vampire} = await loadFixture(fixture);
      await master_vampire.updateDistributionPeriod(666);
      expect(await master_vampire.distributionPeriod()).to.eq(666);
    });
    it('can set dev address', async () => {
      const {master_vampire} = await loadFixture(fixture);
      await master_vampire.updateDevAddress(dev.address);
      expect(await master_vampire.devAddress()).to.eq(dev.address);
      await expect(
        master_vampire.updateDevAddress(carol.address)
      ).to.be.reverted;
      await master_vampire.connect(dev).updateDevAddress(carol.address);
      expect(await master_vampire.devAddress()).to.eq(carol.address);
    });
    it('can set drain address', async () => {
      const {master_vampire} = await loadFixture(fixture);
      await master_vampire.updateDrainAddress(drain.address);
      expect(await master_vampire.drainAddress()).to.eq(drain.address);
    });
    it('can set drain controller', async () => {
      const {master_vampire} = await loadFixture(fixture);
      await master_vampire.updateDrainController(bob.address);
      expect(await master_vampire.drainController()).to.eq(bob.address);
    });
    it('can set reward updater', async () => {
      const {master_vampire} = await loadFixture(fixture);
      await master_vampire.updateRewardUpdaterAddress(bob.address);
      expect(await master_vampire.poolRewardUpdater()).to.eq(bob.address);
    });
  });

  it('early withdrawal penalty works', async () => {
    const {lp, master_vampire, draincontroller} = await loadFixture(fixture);

    // Deposit the Mock LP into the Mock Adapter pool
    await lp.approve(master_vampire.address, utils.parseEther('1000'));

    await master_vampire.updateWithdrawPenalty('500'); // 50% penalty
    await master_vampire.deposit(0, utils.parseEther('1000'), 0);

    // Cool off time should be 24 hours after deposit
    const user_info = await master_vampire.userInfo(0, alice.address);
    let current_block_time = await latestBlockTimestamp();
    expect(user_info.coolOffTime).to.gte(current_block_time);
    expect(user_info.coolOffTime).to.gte(current_block_time.add(duration.hours(23)));

    await advanceBlocks(200);
    await draincontroller.whitelist(carol.address);

    const drainable = await draincontroller.isDrainable();
    expect(drainable.length).to.gt(0);
    await draincontroller.connect(carol).optimalMassDrain(drainable);

    // Withdrawing before cool off incurs penalty
    let alice_eth_balance_before = await alice.getBalance();
    //let pending_weth = await master_vampire.pendingWeth(0, alice.address);

    let tx = await master_vampire.pendingWethReal(0, alice.address);
    let tx_receipt = await tx.wait();

    let pending_weth = tx_receipt.events[0].args.amount;
    console.log("pending weth: ", utils.formatEther(pending_weth.toString()))
    await master_vampire.withdraw(0, utils.parseEther('1000'), 0);
    expect(BigNumber.from(alice_eth_balance_before).sub(pending_weth)).to.lt(BigNumber.from(await alice.getBalance()).sub(pending_weth));

    // Withdrawing after cool off incurs NO penalty
    await lp.approve(master_vampire.address, utils.parseEther('1000'));
    await master_vampire.deposit(0, utils.parseEther('1000'), 0);
    await advanceBlocks(5);
    await advanceBlockAndTime(current_block_time.add(duration.hours(24)).toNumber());
    alice_eth_balance_before = await alice.getBalance();
    //pending_weth = await master_vampire.pendingWeth(0, alice.address);
    tx = await master_vampire.pendingWethReal(0, alice.address);
    tx_receipt = await tx.wait();
    pending_weth = tx_receipt.events[0].args.amount;

    await master_vampire.withdraw(0, utils.parseEther('1000'), 0);
    // Balance must be greater than previous balance + pending reward - gas
    expect(await alice.getBalance()).to.gte(BigNumber.from(alice_eth_balance_before).add(BigNumber.from(pending_weth).div(2)));
  });

  async function runTestWithIBEthStrategy(ibeth_strategy:any, ibeth_token:any) {

    const {weth, lp, drc, rewardpool1, rewardpool2, rewardpool3, draindist, master_vampire,
        draincontroller, tusd_token, master_mock} = await loadFixture(fixture);

    const ibveth = await deployContract(alice, ibeth_strategy, [DRC]);
    await master_vampire.updateIBEthStrategy(ibveth.address);

    console.log("TUSD Balance (MasterMock): ", utils.formatEther((await tusd_token.balanceOf(master_mock.address))).toString());

    // Deposit the Mock LP into the Mock Adapter pool
    await lp.approve(master_vampire.address, utils.parseEther('1000'));
    await master_vampire.deposit(0, utils.parseEther('1000'), 0);

    // Advanced blocks
    await advanceBlocks(10);

    // Expect to have 1000 TUSD (10 blocks/100 per block)
    expect((await master_mock.pendingMock(0, master_vampire.address)).valueOf()).to.eq(utils.parseEther('1000'));
    console.log("Pending reward (alice): ", utils.formatEther((await master_mock.pendingMock(0, master_vampire.address)).toString()));

    console.log("Before Drain:");
    console.log("      WETH Balance (MasterVampire): ", (await weth.balanceOf(master_vampire.address)).toString());
    console.log("  WETH Balance (MockMasterVampire): ", (await weth.balanceOf(master_vampire.address)).toString());
    console.log("               ETH Balance (Carol):", utils.formatEther(await carol.getBalance()).toString());

    await draincontroller.whitelist(carol.address);

    const drainable = await draincontroller.isDrainable();
    expect(drainable.length).to.gt(0);
    await draincontroller.connect(carol).optimalMassDrain(drainable);

    await draindist.setWETHThreshold(utils.parseEther('0.01'));
    await draindist.distribute();

    const ibeth = await ethers.getContractAt('IERC20', ibeth_token);

    console.log("After Drain:");
    console.log("  IBETH Balance (MasterVampire): ", utils.formatEther(await ibeth.balanceOf(master_vampire.address)).toString());
    //console.log("  WETH Balance (MasterVampire): ", utils.formatEther(await ibveth.ethBalance(master_vampire.address)).toString());
    console.log("  WETH Balance (DrainDistributor): ", utils.formatEther(await weth.balanceOf(draindist.address)).toString());
    console.log("  WETH Balance (DrainController): ", utils.formatEther(await weth.balanceOf(draincontroller.address)).toString());
    console.log("  WETH Balance (Dev): ", utils.formatEther(await weth.balanceOf(dev.address)).toString());
    console.log("  WETH Balance (Pool 1): ", utils.formatEther(await weth.balanceOf(rewardpool1.address)).toString());
    console.log("  WETH Balance (Pool 2): ", utils.formatEther(await weth.balanceOf(rewardpool2.address)).toString());
    console.log("  ETH Balance (DrainController):", utils.formatEther(await provider.getBalance(draincontroller.address)).toString());
    console.log("  ETH Balance (Carol):", utils.formatEther(await carol.getBalance()).toString());

    console.log("  Victim Pool (0) Acc WETH: ", utils.formatEther((await master_vampire.poolAccWeth(0)).toString()));
    for (let b = 0; b < 10; b++) {
      console.log("  Pending IBEth reward (alice): ", utils.formatEther((await master_vampire.pendingWeth(0, alice.address)).toString()));
      const tx = await master_vampire.pendingWethReal(0, alice.address);
      const tx_receipt = await tx.wait();
      let pending_weth = tx_receipt.events[0].args.amount;
      console.log("  Pending WETH reward (alice): ", utils.formatEther(pending_weth.toString()))
      await advanceBlock();
    }

    for (let b = 0; b < 200; b++) {
      await advanceBlock();
    }

    console.log("Before Claim:");
    console.log("  Pending reward (alice): ", utils.formatEther((await master_vampire.pendingWeth(0, alice.address)).toString()));
    console.log("  ETH Balance (Alice):", utils.formatEther(await alice.getBalance()).toString());
    await master_vampire.connect(alice).claim(0, 0);
    console.log("After Claim:");
    console.log("  Pending reward (alice): ", utils.formatEther((await master_vampire.pendingWeth(0, alice.address)).toString()));
    console.log("  ETH Balance (Alice):", utils.formatEther(await alice.getBalance()).toString());


    for (let b = 0; b < 300; b++) {
      await advanceBlock();
    }

    console.log("Before Claim (DRC):");
    console.log("  Pending reward (alice): ", utils.formatEther((await master_vampire.pendingWeth(0, alice.address)).toString()));
    console.log("  DRC Balance (Alice):", utils.formatEther(await drc.balanceOf(alice.address)).toString());
    await master_vampire.connect(alice).claim(0, parseInt("0x2"));
    console.log("After Claim (DRC):");
    console.log("  Pending reward (alice): ", utils.formatEther((await master_vampire.pendingWeth(0, alice.address)).toString()));
    console.log("  DRC Balance (Alice):", utils.formatEther(await drc.balanceOf(alice.address)).toString());

  }

  describe('mock adapter should work with mastervampire', () => {
    it('rari capital ibeth strategy', async () => {
      await runTestWithIBEthStrategy(IBVEthRari, REPT);
    });
  });
});