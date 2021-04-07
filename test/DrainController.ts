import { expect } from "chai";
import { Contract, BigNumber, constants, utils } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

import { setupTestDracula } from './helpers/TestFixture';

describe('DrainController', () => {

  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      carol:SignerWithAddress,
      drainController:Contract,
      masterVampire:Contract;

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    carol = await ethers.getSigner(config.carol);

    const DrainController = await deployments.get('DrainController');
    drainController = await ethers.getContractAt('DrainController', DrainController.address, deployer);

    const MasterVampire = await deployments.get('MasterVampire');
    masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, deployer);

    await drainController.setMasterVampire(masterVampire.address);
  });

  describe('setters & getters', () => {
    it('can set master vampire', async () => {
      expect(await drainController.masterVampire()).to.eq(masterVampire.address);
    });
    it('can set weth threshold', async () => {
      expect(await drainController.wethThreshold()).to.eq(utils.parseEther('0.2'));
      await drainController.setWETHThreshold(utils.parseEther('2'));
      expect(await drainController.wethThreshold()).to.eq(utils.parseEther('2'));
    });
  });

  describe('drain', () => {
    it('can whitelist node', async () => {
      await drainController.whitelist(bob.address);
      await drainController.connect(bob).drainPools([]);
    });
    it('can unwhitelist node', async () => {
      await drainController.unWhitelist(bob.address);
      await expect(
        drainController.connect(bob).drainPools([])
      ).to.be.reverted;
    });
    it('is drainable', async () => {
      const drainable = await drainController.isDrainable();
      expect(drainable.length).to.eq(1);
    });
    it('node gas fee is paid', async () => {
      await drainController.whitelist(bob.address);
      await alice.sendTransaction({
        to: drainController.address,
        value: utils.parseEther('1')
      });
      expect(await provider.getBalance(drainController.address)).to.eq(utils.parseEther('1'));
      await drainController.connect(bob).drainPools([]);
      expect(await provider.getBalance(drainController.address)).to.lt(utils.parseEther('1'));
      expect(await bob.getBalance()).to.gte(utils.parseEther('10000'));
    });
    it('chi tokens work', async () => {
      const CHI = await deployments.get('MockChiToken');
      const chi = await ethers.getContractAt('MockChiToken', CHI.address, deployer);
      await chi.connect(bob).mint('50', {gasPrice: 20});

      await drainController.whitelist(bob.address);
      await alice.sendTransaction({
        to: drainController.address,
        value: utils.parseEther('0.00001')
      });

      expect(await provider.getBalance(drainController.address)).to.eq(utils.parseEther('0.00001'));
      await chi.connect(bob).approve(drainController.address, constants.MaxUint256);
      const drainable = await drainController.isDrainable();
      // Filter pools that haven't hit drain threshold
      const filtered_drain = drainable.filter(function(d:number) { return d !== -1 })
      await drainController.connect(bob).drainPools(filtered_drain);
      expect(await chi.balanceOf(bob.address)).to.lt(50);
      expect(await provider.getBalance(drainController.address)).to.lt(utils.parseEther('0.00001'));
      expect(await bob.getBalance()).to.gte(utils.parseEther('9999.1'));
    });
  });

  describe('destruct contract', () => {
    it('can withdraw ETH', async () => {
      await bob.sendTransaction({
        to: drainController.address,
        value: utils.parseEther('5')
      });
      await expect(
        drainController.connect(bob).withdrawETH(carol.address)
      ).to.be.reverted;
      await drainController.withdrawETH(carol.address);
      expect(await carol.getBalance()).to.eq(utils.parseEther('10005'));
    });
    it('can destruct and claim eth balance', async () => {
      await expect(
        drainController.connect(bob).kill(carol.address)
      ).to.be.reverted;
      await drainController.kill(carol.address);
    });
  });
});
