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
import LiquidityController from '../artifacts/contracts/LiquidityController.sol/LiquidityController.json';

describe('LiquidityController', () => {
  const wallets = provider.getWallets();
  const [alice, bob, carol, dev, node] = wallets;

  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

  async function fixture(allwallets:any) {
    const weth = await ethers.getContractAt('IWETH', WETH);
    const lpcontroller = await deployContract(alice, LiquidityController);
    return {weth, lpcontroller};
  }

  describe('distribute', () => {
    it('can add liquidity', async () => {
      const {weth, lpcontroller} = await loadFixture(fixture);

      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('0'));
      await weth.deposit({value : utils.parseEther('5')});
      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('5'));
      await weth.approve(lpcontroller.address, constants.MaxUint256);
      await lpcontroller.addLiquidity(utils.parseEther('1'));
      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('4'));
    });
  });
});