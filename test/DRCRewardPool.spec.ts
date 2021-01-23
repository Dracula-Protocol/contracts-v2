import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
const { waffle, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

const loadFixture = waffle.createFixtureLoader(
  provider.getWallets(),
  provider
);

import DRCRewardPool from '../artifacts/contracts/DRCRewardPool.sol/DRCRewardPool.json';
import DraculaToken from '../artifacts/contracts/DraculaToken.sol/DraculaToken.json';

describe('DRCRewardPool', () => {
  const wallets = provider.getWallets();
  const [alice, bob] = wallets;

  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

  async function fixture(allwallets:any) {
    const DURATION = 604800; // 7 days
    const weth = await ethers.getContractAt('IWETH', WETH);
    await weth.deposit({value : utils.parseEther('5000')});
    const drc = await deployContract(alice, DraculaToken);
    const reward_pool = await deployContract(alice, DRCRewardPool, [weth.address, drc.address, DURATION, alice.address]);
    await weth.approve(reward_pool.address, constants.MaxUint256);
    return {weth, drc, reward_pool};
  }

  it('Can stake and withdraw', async () => {
    const {weth, drc, reward_pool} = await loadFixture(fixture);
    await drc.mint(alice.address, utils.parseEther('1000'));
    await drc.approve(reward_pool.address, constants.MaxUint256);

    await reward_pool.stake(utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(0);
    expect(await reward_pool.balanceOf(alice.address)).to.eq(utils.parseEther('1000'));

    await reward_pool.unstake(utils.parseEther('1000'));
    expect(await drc.balanceOf(alice.address)).to.eq(utils.parseEther('990')); // 1000 - 1% burn fee
    expect(await reward_pool.balanceOf(alice.address)).to.eq(0);
  });

  it('Can set burn rate', async () => {
    const {weth, drc, reward_pool} = await loadFixture(fixture);
    await reward_pool.setBurnRate(5);
    expect(await reward_pool.burnRate()).to.eq(5);
    await expect(
        reward_pool.burnRate(50)
    ).to.be.reverted;
  });
});