import { expect } from 'chai'
import { Contract, BigNumber, constants, utils } from 'ethers'
const { waffle, network, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

import { advanceBlockTo, latestBlockTimestamp } from './utils';

import DrainController from '../artifacts/contracts/DrainController.sol/DrainController.json';
import VampireAdapter from '../artifacts/contracts/VampireAdapter.sol/VampireAdapter.json';

describe('DrainController', () => {
  const wallets = provider.getWallets();
  const [alice, bob, carol, dev, draindist, drc, node] = wallets;
  let drain_controller: Contract;
  let master_vampire: Contract;

  beforeEach(async () => {
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

    drain_controller = await DC.deploy(dev.address);
    master_vampire = await MV.deploy(drc.address, draindist.address);
  });

  describe('setters & getters', () => {
    it('can set drain distributor', async () => {
      await drain_controller.setDrainDistributor(draindist.address);
      expect(await drain_controller.drainDistributor()).to.eq(draindist.address);
    });
    it('can set master vampire', async () => {
      await drain_controller.setMasterVampire(master_vampire.address);
      expect(await drain_controller.masterVampire()).to.eq(master_vampire.address);
    });
    it('can set weth threshold', async () => {
      expect(await drain_controller.wethThreshold()).to.eq(utils.parseEther('0.2'));
      await drain_controller.setWETHThreshold(utils.parseEther('2'));
      expect(await drain_controller.wethThreshold()).to.eq(utils.parseEther('2'));
    });
  });

  describe('drain', () => {
    it('can whitelist node', async () => {
      await drain_controller.setMasterVampire(master_vampire.address);
      await drain_controller.whitelist(node.address);
      await drain_controller.connect(node).optimalMassDrain();
    });
    it('can unwhitelist node', async () => {
      await drain_controller.unWhitelist(node.address);
      await expect(
        drain_controller.connect(node).optimalMassDrain()
      ).to.be.reverted;
    });
    it('is drainable', async () => {
      await drain_controller.setMasterVampire(master_vampire.address);
      const drainable = await drain_controller.isDrainable();
      expect(drainable).to.eq(false);
    });
    it('node gas fee is paid', async () => {
      await drain_controller.setMasterVampire(master_vampire.address);
      await drain_controller.whitelist(node.address);
      await bob.sendTransaction({
        to: drain_controller.address,
        value: utils.parseEther('1')
      });
      expect(await provider.getBalance(drain_controller.address)).to.eq(utils.parseEther('1'));
      await drain_controller.connect(node).optimalMassDrain();
      expect(await provider.getBalance(drain_controller.address)).to.lt(utils.parseEther('1'));
      expect(await node.getBalance()).to.gte(utils.parseEther('10000'));
    });
    it('chi tokens work', async () => {
      const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
      const CHI = '0x0000000000004946c0e9F43F4Dee607b0eF1fA1c';
      const weth = await ethers.getContractAt('IERC20', WETH);
      const chi = await ethers.getContractAt('IChiToken', CHI);
      await chi.connect(node).mint('100', {gasPrice: 20});

      await drain_controller.setMasterVampire(master_vampire.address);
      await drain_controller.whitelist(node.address);
      await bob.sendTransaction({
        to: drain_controller.address,
        value: utils.parseEther('0.00001')
      });

      //console.log((await chi.balanceOf(node.address)).toString())
      expect(await provider.getBalance(drain_controller.address)).to.eq(utils.parseEther('0.00001'));
      await chi.approve(drain_controller.address, constants.MaxUint256);
      await drain_controller.connect(node).optimalMassDrain();
      //console.log((await chi.balanceOf(node.address)).toString())
      expect(await provider.getBalance(drain_controller.address)).to.lt(utils.parseEther('0.00001'));
      //expect(await node.getBalance()).to.gte(utils.parseEther('10000'));
    });
  });

  describe('destruct contract', () => {
    it('can withdraw ETH', async () => {
      await bob.sendTransaction({
        to: drain_controller.address,
        value: utils.parseEther('5')
      });
      await expect(
        drain_controller.connect(node).withdrawETH(carol.address)
      ).to.be.reverted;
      await drain_controller.withdrawETH(carol.address);
      expect(await carol.getBalance()).to.eq(utils.parseEther('10005'));
    });
    it('can destruct and claim eth balance', async () => {
      await expect(
        drain_controller.connect(node).kill(carol.address)
      ).to.be.reverted;
      await drain_controller.kill(carol.address);
    });
  });
});