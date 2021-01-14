import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
const { waffle, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

const loadFixture = waffle.createFixtureLoader(
  provider.getWallets(),
  provider
);

import { advanceBlockTo, advanceBlockAndTime, latestBlockTimestamp } from './utils';
import RewardPool from '../artifacts/contracts/RewardPool.sol/RewardPool.json';
import DraculaToken from '../artifacts/contracts/DraculaToken.sol/DraculaToken.json';

describe('RewardPool', () => {
  const wallets = provider.getWallets();
  const [alice, bob, carol, dev] = wallets;

  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
  const DRC_ETH_LP = '0x276e62c70e0b540262491199bc1206087f523af6';
  const DURATION = 604800; // 7 days

  async function fixture(allwallets:any) {
    const weth = await ethers.getContractAt('IWETH', WETH);
    await weth.deposit({value : utils.parseEther('5000')});
    const lp = await ethers.getContractAt('IERC20', DRC_ETH_LP);
    const drc = await deployContract(alice, DraculaToken);
    const reward_pool = await deployContract(alice, RewardPool, [weth.address, drc.address, DURATION, alice.address]);
    await weth.approve(reward_pool.address, constants.MaxUint256);
    return {weth, lp, drc, reward_pool};
  }

  it('Can stake and withdraw', async () => {
    const {weth, lp, drc, reward_pool} = await loadFixture(fixture);

    await drc.mint(alice.address, utils.parseEther('1000'));

    await drc.approve(reward_pool.address, constants.MaxUint256);
    await reward_pool.stake(utils.parseEther('1000'));

    console.log("DRC balance: ", (await drc.balanceOf(alice.address)).toString()); // 0
    console.log("Staked balance: ", (await reward_pool.balanceOf(alice.address)).toString()); // 1000

    console.log("Withdrawing...");
    await reward_pool.unstake(utils.parseEther('1000'));
    console.log("Staked balance: ", (await reward_pool.balanceOf(alice.address)).toString()); // 0
    console.log("DRC balance: ", (await drc.balanceOf(alice.address)).toString()); // 1000 - burn fee
  });

  /*it('Can set burn rate', async () => {
    const drc = await DraculaToken.new();
    const DURATION = 604800; // 7 days
    const reward_pool = await RewardPool.new(drc.address, drc.address, DURATION, alice.address);
    await reward_pool.setBurnRate(5);

    await truffleAssert.reverts(reward_pool.setBurnRate(20), "Invalid burn rate value");
  });*/

  it('Can unstake', async () => {
    const {weth, lp, drc, reward_pool} = await loadFixture(fixture);

    // User 0 stake
    await drc.mint(alice.address, utils.parseEther('1000'));
    await drc.approve(reward_pool.address, constants.MaxUint256);
    await reward_pool.stake(utils.parseEther('1000'));

    // Fund the reward_pool
    await drc.mint(alice.address, utils.parseEther('5000'));
    await reward_pool.fundPool(utils.parseEther('5000'));

    await advanceBlockAndTime(DURATION);

    console.log("Earned0: ", (await reward_pool.earned(alice.address)).toString())

    await reward_pool.unstake(utils.parseEther('1000'));

    console.log("DRC balance: ", (await drc.balanceOf(alice.address)).toString());
  });

  it('Can withdraw', async () => {
    const {weth, lp, drc, reward_pool} = await loadFixture(fixture);

    await drc.mint(alice.address, utils.parseEther('100'));

    const DURATION = 7200; // 2 hours

    // User 0 stake
    await drc.approve(reward_pool.address, constants.MaxUint256);
    await reward_pool.stake(utils.parseEther('50'));

    console.log("User reward paid: ", (await reward_pool.userRewardPerTokenPaid(alice.address)).toString())

    // Fund the reward_pool
    await drc.mint(alice.address, utils.parseEther('100'));
    await reward_pool.fundPool(utils.parseEther('100'));

    await reward_pool.stake(utils.parseEther('20'));

    console.log("User reward paid: ", (await reward_pool.userRewardPerTokenPaid(alice.address)).toString())

    await advanceBlockAndTime(DURATION*1.7);

    await drc.mint(alice.address, utils.parseEther('100'));
    await reward_pool.fundPool(utils.parseEther('100'));

    await reward_pool.stake(utils.parseEther('30'));


    await advanceBlockAndTime(DURATION*2.5);

    console.log("Before withdraw:")
    console.log("Total Rewards avail: ", (await drc.balanceOf(reward_pool.address)).sub((await reward_pool.totalStaked())).toString());
    console.log("Total Staked: ", (await reward_pool.totalStaked()).toString())
    console.log("Earned0: ", (await reward_pool.earned(alice.address)).toString())
    console.log("DRC balance: ", (await drc.balanceOf(alice.address)).toString());

    await reward_pool.unstake(utils.parseEther('100'));

    console.log("After withdraw:")
    console.log("Total Rewards avail: ", (await drc.balanceOf(reward_pool.address)).toString());
    console.log("Total Staked: ", (await reward_pool.totalStaked()).toString())
    console.log("Earned0 : ", (await reward_pool.earned(alice.address)).toString())
    console.log("DRC balance (minus burn): ", (await drc.balanceOf(alice.address)).toString());
  });

  it('Can earn rewards', async () => {
    const {weth, lp, drc, reward_pool} = await loadFixture(fixture);

    await drc.mint(alice.address, utils.parseEther('100'));
    await drc.mint(bob.address, utils.parseEther('100'));

    // User 0 stake
    await drc.approve(reward_pool.address, constants.MaxUint256);
    await reward_pool.stake(utils.parseEther('100'));

    // Fund the reward_pool
    await drc.mint(alice.address, utils.parseEther('200'));
    await reward_pool.fundPool(utils.parseEther('200'));

    // User 1 stake
    await drc.connect(bob).approve(reward_pool.address, constants.MaxUint256);
    await reward_pool.connect(bob).stake(utils.parseEther('100'));

    // Users will have half the weekly reward shared
    await advanceBlockAndTime(DURATION/2);

    console.log("Half Earned0: ", utils.formatEther(await reward_pool.earned(alice.address)))
    console.log("Half Earned1: ", utils.formatEther(await reward_pool.earned(bob.address)))

    await drc.mint(alice.address, utils.parseEther('100'));
    await reward_pool.fundPool(utils.parseEther('100'));

    // Users will have half the weekly reward shared
    console.log("Earned0: ", utils.formatEther(await reward_pool.earned(alice.address)))
    console.log("Earned1: ", utils.formatEther(await reward_pool.earned(bob.address)))

    await advanceBlockAndTime(DURATION/2);

    // Users will have the entire weekly reward shared
    console.log("Earned0: ", utils.formatEther(await reward_pool.earned(alice.address)))
    console.log("Earned1: ", utils.formatEther(await reward_pool.earned(bob.address)))
  });
});