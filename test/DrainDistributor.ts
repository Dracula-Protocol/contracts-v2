import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");

import { setupTestDracula } from './helpers/TestFixture';

describe('DrainDistributor', () => {
  let deployer,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      carol:SignerWithAddress,
      drc,
      dai,
      router,
      weth:Contract,
      drain_distributor:Contract,
      uniRewardPool:Contract,
      drcRewardPool:Contract;

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = config.deployer;
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    carol = await ethers.getSigner(config.carol);
    drc = config.drc;
    dai = config.dai;
    router = config.router;

    const WETH = await deployments.get('WETH');
    weth = await ethers.getContractAt('MockWETH', WETH.address, deployer);

    const DrainDistributor = await deployments.get('DrainDistributor');
    drain_distributor = await ethers.getContractAt('DrainDistributor', DrainDistributor.address, deployer);

    const UniRewardPool = await deployments.get('UniRewardPool');
    uniRewardPool = await ethers.getContractAt('RewardPool', UniRewardPool.address, deployer);
    const DRCRewardPool = await deployments.get('DRCRewardPool');
    drcRewardPool = await ethers.getContractAt('DRCRewardPool', DRCRewardPool.address, deployer);
  });

  describe('setters & getters', () => {
    it('can set dev', async () => {
      await drain_distributor.changeDev(carol.address);
      expect(await drain_distributor.devFund()).to.eq(carol.address);
    });
    it('can set reward pools', async () => {
      expect(await drain_distributor.uniRewardPool()).to.not.eq(bob.address);
      await drain_distributor.changeUniRewardPool(bob.address);
      expect(await drain_distributor.uniRewardPool()).to.eq(bob.address);
      expect(await drain_distributor.drcRewardPool()).to.not.eq(alice.address);
      await drain_distributor.changeDRCRewardPool(alice.address);
      expect(await drain_distributor.drcRewardPool()).to.eq(alice.address);
    });
    it('can set drain controller', async () => {
      await drain_distributor.changeDrainController(bob.address);
      expect(await drain_distributor.drainController()).to.eq(bob.address);
    });
    it('can set distribution', async () => {
      expect(await drain_distributor.gasShare()).to.eq(100);
      expect(await drain_distributor.devShare()).to.eq(250);
      expect(await drain_distributor.uniRewardPoolShare()).to.eq(400);
      expect(await drain_distributor.drcRewardPoolShare()).to.eq(250);
      await drain_distributor.changeDistribution(200, 200, 300, 300);
      expect(await drain_distributor.gasShare()).to.eq(200);
      expect(await drain_distributor.devShare()).to.eq(200);
      expect(await drain_distributor.uniRewardPoolShare()).to.eq(300);
      expect(await drain_distributor.drcRewardPoolShare()).to.eq(300);
      await expect(
        drain_distributor.changeDistribution(200, 100, 300, 200)
      ).to.be.reverted;
    });
  });

  describe('distribute', () => {
    it('can distribute rewards', async () => {
      await drain_distributor.changeDev(bob.address);
      await drain_distributor.changeDrainController(carol.address);

      await weth.deposit({value : utils.parseEther('5')});
      await weth.transfer(drain_distributor.address, utils.parseEther('1'));

      expect(await weth.balanceOf(drain_distributor.address)).to.eq(utils.parseEther('1'));
      await drain_distributor.distribute();
      expect(await carol.getBalance()).to.eq(utils.parseEther('10000.1'));
      expect(await weth.balanceOf(bob.address)).to.eq(utils.parseEther('0.25'));
      expect(await weth.balanceOf(uniRewardPool.address)).to.eq(utils.parseEther('0.4'));
      expect(await weth.balanceOf(drcRewardPool.address)).to.eq(utils.parseEther('0.25'));

      await weth.transfer(drain_distributor.address, utils.parseEther('1'));
      await drain_distributor.distribute();
      expect(await carol.getBalance()).to.eq(utils.parseEther('10000.2'));
      expect(await weth.balanceOf(bob.address)).to.eq(utils.parseEther('0.5'));
      expect(await weth.balanceOf(uniRewardPool.address)).to.eq(utils.parseEther('0.8'));
      expect(await weth.balanceOf(drcRewardPool.address)).to.eq(utils.parseEther('0.5'));
    });
  });
});
