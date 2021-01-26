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
  const DRC_ETH_LP = '0x276e62c70e0b540262491199bc1206087f523af6';

  async function fixture(allwallets:any) {
    const weth = await ethers.getContractAt('IWETH', WETH);
    const lp = await ethers.getContractAt('IERC20', DRC_ETH_LP);
    const lpcontroller = await deployContract(alice, LiquidityController);
    await lpcontroller.changeLPDestination(dev.address);
    return {weth, lp, lpcontroller};
  }

  describe('distribute', () => {
    it('weth threshold works', async () => {
      const {weth, lp, lpcontroller} = await loadFixture(fixture);
      expect(await lpcontroller.wethThreshold()).to.eq(utils.parseEther('0.2'));
      await lpcontroller.setWETHThreshold(utils.parseEther('0.3'));
      expect(await lpcontroller.wethThreshold()).to.eq(utils.parseEther('0.3'));
      await weth.deposit({value : utils.parseEther('5')});
      await weth.approve(lpcontroller.address, constants.MaxUint256);
      await lpcontroller.addLiquidity(utils.parseEther('0.01'));
      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('4.99'));
      expect(await lp.balanceOf(dev.address)).to.eq(utils.parseEther('0'));
    });
    it('can add liquidity', async () => {
      const {weth, lp, lpcontroller} = await loadFixture(fixture);

      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('0'));
      await weth.deposit({value : utils.parseEther('5')});
      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('5'));
      await weth.approve(lpcontroller.address, constants.MaxUint256);
      await lpcontroller.addLiquidity(utils.parseEther('1'));
      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('4'));
      expect(await lp.balanceOf(dev.address)).to.gt(utils.parseEther('0'));
    });
    it('destruct', async () => {
      const {weth, lp, lpcontroller} = await loadFixture(fixture);
      await expect(
        lpcontroller.connect(node).kill(carol.address)
      ).to.be.reverted;

      expect(await weth.balanceOf(alice.address)).to.eq(utils.parseEther('0'));
      expect(await weth.balanceOf(carol.address)).to.eq(utils.parseEther('0'));
      await weth.deposit({value : utils.parseEther('5')});
      await lpcontroller.setWETHThreshold(utils.parseEther('1'));
      await weth.approve(lpcontroller.address, constants.MaxUint256);
      await lpcontroller.addLiquidity(utils.parseEther('0.5'));
      await lpcontroller.kill(carol.address);
      expect(await weth.balanceOf(carol.address)).to.eq(utils.parseEther('0.5'));
    });
  });
});