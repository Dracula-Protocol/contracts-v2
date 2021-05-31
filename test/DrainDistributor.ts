import { expect } from 'chai'
import { Contract, utils } from 'ethers'
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const {  ethers, deployments } = require("hardhat");

import { setupTestDracula } from './helpers/TestFixture';

describe('DrainDistributor', () => {
  let deployer,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      carol:SignerWithAddress,
      drc:Contract,
      router,
      weth:Contract,
      drain_distributor:Contract,
      lpRewardPool:Contract,
      drcRewardPool:Contract;

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = config.deployer;
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    carol = await ethers.getSigner(config.carol);
    drc = config.drc;
    router = config.router;

    const WETH = await deployments.get('WETH');
    weth = await ethers.getContractAt('MockWETH', WETH.address, deployer);

    const DrainDistributor = await deployments.get('DrainDistributor');
    drain_distributor = await ethers.getContractAt('DrainDistributor', DrainDistributor.address, deployer);

    const LPRewardPool = await deployments.get('LPRewardPool');
    lpRewardPool = await ethers.getContractAt('RewardPool', LPRewardPool.address, deployer);
    const DRCRewardPool = await deployments.get('DraculaHoard');
    drcRewardPool = await ethers.getContractAt('DraculaHoard', DRCRewardPool.address, deployer);
  });

  describe('setters & getters', () => {
    it('can set treasury', async () => {
      await drain_distributor.changeTreasury(carol.address);
      expect(await drain_distributor.treasury()).to.eq(carol.address);
    });
    it('can set reward pools', async () => {
      expect(await drain_distributor.lpRewardPool()).to.not.eq(bob.address);
      await drain_distributor.changeLPRewardPool(bob.address);
      expect(await drain_distributor.lpRewardPool()).to.eq(bob.address);
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
      expect(await drain_distributor.treasuryShare()).to.eq(250);
      expect(await drain_distributor.lpRewardPoolShare()).to.eq(400);
      expect(await drain_distributor.drcRewardPoolShare()).to.eq(250);
      await drain_distributor.changeDistribution(200, 200, 300, 300);
      expect(await drain_distributor.gasShare()).to.eq(200);
      expect(await drain_distributor.treasuryShare()).to.eq(200);
      expect(await drain_distributor.lpRewardPoolShare()).to.eq(300);
      expect(await drain_distributor.drcRewardPoolShare()).to.eq(300);
      await expect(
        drain_distributor.changeDistribution(200, 100, 300, 200)
      ).to.be.reverted;
    });
  });

  describe('distribute', () => {
    it('can distribute rewards', async () => {
      await drain_distributor.changeTreasury(bob.address);
      await drain_distributor.changeDrainController(carol.address);

      await weth.deposit({value : utils.parseEther('5')});
      await weth.transfer(drain_distributor.address, utils.parseEther('1'));

      expect(await weth.balanceOf(drain_distributor.address)).to.eq(utils.parseEther('1'));
      await drain_distributor.distribute();
      expect(await weth.balanceOf(drain_distributor.address)).to.eq(utils.parseEther('0'));
      expect(await carol.getBalance()).to.eq(utils.parseEther('10000.1'));
      expect(await weth.balanceOf(bob.address)).to.eq(utils.parseEther('0.25'));
      expect(await weth.balanceOf(lpRewardPool.address)).to.eq(utils.parseEther('0.4'));
      expect(await weth.balanceOf(drcRewardPool.address)).to.eq(utils.parseEther('0'));
      expect(await drc.balanceOf(drcRewardPool.address)).to.be.gt(utils.parseEther('0'));

      await weth.transfer(drain_distributor.address, utils.parseEther('1'));
      await drain_distributor.distribute();
      expect(await weth.balanceOf(drain_distributor.address)).to.eq(utils.parseEther('0'));
      expect(await carol.getBalance()).to.eq(utils.parseEther('10000.2'));
      expect(await weth.balanceOf(bob.address)).to.be.gte(utils.parseEther('0.5'));
      expect(await weth.balanceOf(lpRewardPool.address)).to.be.gte(utils.parseEther('0.8'));
      expect(await weth.balanceOf(drcRewardPool.address)).to.eq(utils.parseEther('0'));
      expect(await drc.balanceOf(drcRewardPool.address)).to.be.gt(utils.parseEther('0'));
    });
  });
});
