import { expect } from "chai";
import { Contract, BigNumber, constants, utils } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { waffle, ethers, deployments } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

import { setupTestDracula } from './helpers/TestFixture';
import {
  advanceBlock,
  advanceBlocks,
  advanceBlockAndTime,
  latestBlockTimestamp,
  duration
} from './helpers/Utils';

async function drain(drainer:any, drainController:Contract, drainDistributor:Contract) {
  let drainable = await drainController.isDrainable();
  // Filter pools that haven't hit drain threshold
  let filtered_drain = drainable.filter(function(d:number) { return d !== -1 })
  expect(filtered_drain.length).to.gt(0);
  await drainController.connect(drainer).drainPools(filtered_drain);
  await drainDistributor.distribute();
}

describe('MasterVampire', () => {

  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      carol:SignerWithAddress,
      tom:SignerWithAddress,
      treasury:SignerWithAddress,
      weth:Contract,
      drc:Contract,
      drainController:Contract,
      drainDistributor:Contract,
      masterVampire:Contract,
      mockMasterChef:Contract,
      mockLP:Contract,
      mockChefAdapter:Contract;

  beforeEach(async () => {
    const config = await setupTestDracula();
    deployer = await ethers.getSigner(config.deployer);
    alice = await ethers.getSigner(config.alice);
    bob = await ethers.getSigner(config.bob);
    carol = await ethers.getSigner(config.carol);
    tom = await ethers.getSigner(config.tom);
    treasury = await ethers.getSigner(config.treasury);
    weth = config.weth;
    drc = config.drc;

    const DrainController = await deployments.get('DrainController');
    drainController = await ethers.getContractAt('DrainController', DrainController.address, deployer);

    const DrainDistributor = await deployments.get('DrainDistributor');
    drainDistributor = await ethers.getContractAt('DrainDistributor', DrainDistributor.address, deployer);

    const MasterVampire = await deployments.get('MasterVampire');
    masterVampire = await ethers.getContractAt('MasterVampire', MasterVampire.address, deployer);

    const MockMasterChef = await deployments.get('MockMasterChef');
    mockMasterChef = await ethers.getContractAt('MockMasterChef', MockMasterChef.address, deployer);

    const MockMasterChefToken = await deployments.get('MockMasterChefToken');
    const MockChefLP = await deployments.get('MockChefLP');
    mockLP = await ethers.getContractAt('MockERC20', MockChefLP.address, deployer);
    const MockChefAdapter = await deployments.get('MockChefAdapter');
    mockChefAdapter = await ethers.getContractAt('MockAdapter', MockChefAdapter.address, deployer);

    await drainController.setMasterVampire(masterVampire.address);
    await drainController.setWETHThreshold(utils.parseEther('0.01'));
    await drainDistributor.setWETHThreshold(utils.parseEther('0.01'));
  });

  describe('setters & getters', () => {
    it('can set distribution period', async () => {
      await masterVampire.updateDistributionPeriod(666);
      expect(await masterVampire.distributionPeriod()).to.eq(666);
    });
    it('can set dev address', async () => {
      await masterVampire.updateDevAddress(treasury.address);
      expect(await masterVampire.devAddress()).to.eq(treasury.address);
      await expect(
        masterVampire.updateDevAddress(carol.address)
      ).to.be.reverted;
      await masterVampire.connect(treasury).updateDevAddress(carol.address);
      expect(await masterVampire.devAddress()).to.eq(carol.address);
    });
    it('can set drain address', async () => {
      await masterVampire.updateDrainAddress(bob.address);
      expect(await masterVampire.drainAddress()).to.eq(bob.address);
    });
    it('can set drain controller', async () => {
      await masterVampire.updateDrainController(bob.address);
      expect(await masterVampire.drainController()).to.eq(bob.address);
    });
    it('can set reward updater', async () => {
      await masterVampire.updateRewardUpdaterAddress(bob.address);
      expect(await masterVampire.poolRewardUpdater()).to.eq(bob.address);
    });
  });

  it('can withdraw', async () => {
    await mockLP.mint(alice.address, utils.parseEther('3000'));

    // Deposit the Mock LP into the Mock Adapter pool
    await mockLP.connect(alice).approve(masterVampire.address, utils.parseEther('1000'));
    await masterVampire.connect(alice).deposit(0, utils.parseEther('1000'));
    await masterVampire.connect(alice).withdraw(0, utils.parseEther('1000'), 0);

    // TODO check balances
  });

  describe('mock adapter should work with mastervampire', () => {
    it('yearn yvWETH strategy', async () => {

      await drainController.whitelist(carol.address);

      // Deposit the Mock LP into the Mock Adapter pool
      await mockLP.mint(alice.address, utils.parseEther('1000'));
      await mockLP.connect(alice).approve(masterVampire.address, utils.parseEther('1000'));
      await masterVampire.connect(alice).deposit(0, utils.parseEther('1000'));

      await mockLP.mint(bob.address, utils.parseEther('500'));
      await mockLP.connect(bob).approve(masterVampire.address, utils.parseEther('500'));
      await masterVampire.connect(bob).deposit(0, utils.parseEther('500'));

      // Advanced blocks
      await advanceBlocks(10);

      expect((await mockMasterChef.pendingMock(0, masterVampire.address)).valueOf()).to.eq(utils.parseEther('0.066666666'));
      await drain(carol, drainController, drainDistributor);
      expect((await mockMasterChef.pendingMock(0, masterVampire.address)).valueOf()).to.eq(utils.parseEther('0.006666666'));

      const StrategyYearn = await deployments.get('StrategyYearn');
      const strategyYearn = await ethers.getContractAt('IBVEthRari', StrategyYearn.address, deployer);
      const ibToken = await ethers.getContractAt('IERC20', await strategyYearn.ibToken(), deployer);

      expect(await ibToken.balanceOf(masterVampire.address)).to.gt(0);
      /*console.log("After Drain:");
      console.log("  IBETH Balance (MasterVampire): ", utils.formatEther(await ibToken.balanceOf(masterVampire.address)).toString());
      console.log("  WETH Balance (DrainDistributor): ", utils.formatEther(await weth.balanceOf(drainDistributor.address)).toString());
      console.log("  WETH Balance (Dev): ", utils.formatEther(await weth.balanceOf(treasury.address)).toString());
      console.log("  WETH Balance (Pool 1): ", utils.formatEther(await weth.balanceOf(rewardpool1.address)).toString());
      console.log("  WETH Balance (Pool 2): ", utils.formatEther(await weth.balanceOf(rewardpool2.address)).toString());
      console.log("  ETH Balance (DrainController):", utils.formatEther(await provider.getBalance(drainController.address)).toString());
      console.log("  ETH Balance (Carol):", utils.formatEther(await carol.getBalance()).toString());

      console.log("  Victim Pool (0) Acc WETH: ", utils.formatEther((await masterVampire.poolAccWeth(0)).toString()));*/

      let last_pending_weth_alice = BigNumber.from(0);
      let last_pending_weth_bob = BigNumber.from(0);
      for (let b = 0; b < 10; b++) {
        let pending_weth = await masterVampire.callStatic.pendingWethReal(0, alice.address);
        expect(pending_weth).to.gt(last_pending_weth_alice);
        last_pending_weth_alice = pending_weth;

        pending_weth = await masterVampire.callStatic.pendingWethReal(0, bob.address);
        expect(pending_weth).to.gt(last_pending_weth_bob);
        last_pending_weth_bob = pending_weth;
        await advanceBlock();
      }

      expect((await mockMasterChef.pendingMock(0, masterVampire.address)).valueOf()).to.eq(utils.parseEther('0.073333332'));

      await mockLP.mint(tom.address, utils.parseEther('500'));
      await mockLP.connect(tom).approve(masterVampire.address, utils.parseEther('500'));
      await masterVampire.connect(tom).deposit(1, utils.parseEther('500'));

      await advanceBlocks(9000);

      // No stealing of rewards from other pools :/
      await drainController.connect(carol).drainPools([1]);
      await masterVampire.connect(tom).claim(1, 0);

      /*console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      console.log("  Pending reward (bob): ", utils.formatEther((await masterVampire.pendingWeth(0, bob.address)).toString()));

      const ethBeforeClaim = await alice.getBalance();
      console.log("Before Claim:");
      console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      console.log("  ETH Balance (Alice):", utils.formatEther(await alice.getBalance()).toString());
      await masterVampire.connect(alice).claim(0, 0);
      console.log("After Claim:");
      console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      console.log("  ETH Balance (Alice):", utils.formatEther(await alice.getBalance()).toString());
      expect(await alice.getBalance()).to.gt(ethBeforeClaim);

      console.log("Before Claim:");
      console.log("  Pending reward (bob): ", utils.formatEther((await masterVampire.pendingWeth(0, bob.address)).toString()));
      console.log("  ETH Balance (bob):", utils.formatEther(await bob.getBalance()).toString());*/
      await masterVampire.connect(alice).claim(0, 0);
      await masterVampire.connect(bob).claim(0, 0);
      /*console.log("After Claim:");
      console.log("  Pending reward (bob): ", utils.formatEther((await masterVampire.pendingWeth(0, bob.address)).toString()));
      console.log("  ETH Balance (bob):", utils.formatEther(await bob.getBalance()).toString());*/

      await drain(carol,drainController, drainDistributor);
      expect((await mockMasterChef.pendingMock(0, masterVampire.address)).valueOf()).to.eq(utils.parseEther('0.0049999995'));

      await advanceBlocks(2000);

      await drain(carol,drainController, drainDistributor);

      last_pending_weth_alice = BigNumber.from(0);
      last_pending_weth_bob = BigNumber.from(0);
      let last_pending_weth_tom = BigNumber.from(0);
      for (let b = 0; b < 10; b++) {
        //console.log("  Pending IBEth reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
        let pending_weth = await masterVampire.callStatic.pendingWethReal(0, alice.address);
        console.log("  Pending WETH reward (alice): ", utils.formatEther(pending_weth.toString()))
        expect(pending_weth).to.gt(last_pending_weth_alice);
        last_pending_weth_alice = pending_weth;

        pending_weth = await masterVampire.callStatic.pendingWethReal(0, bob.address);
        console.log("  Pending WETH reward (bob): ", utils.formatEther(pending_weth.toString()))
        expect(pending_weth).to.gt(last_pending_weth_bob);
        last_pending_weth_bob = pending_weth;

        pending_weth = await masterVampire.callStatic.pendingWethReal(1, tom.address);
        console.log("  Pending WETH reward (tom): ", utils.formatEther(pending_weth.toString()))
        expect(pending_weth).to.gt(last_pending_weth_tom);
        last_pending_weth_tom = pending_weth;
        await advanceBlock();
      }

      expect(await drc.balanceOf(alice.address)).to.eq(0);
      console.log("Before Claim (DRC):");
      console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      console.log("  DRC Balance (Alice):", utils.formatEther(await drc.balanceOf(alice.address)).toString());
      await masterVampire.connect(alice).claim(0, parseInt("0x2"));
      console.log("After Claim (DRC):");
      console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      console.log("  DRC Balance (Alice):", utils.formatEther(await drc.balanceOf(alice.address)).toString());
      expect(await drc.balanceOf(alice.address)).to.gt(0);
    });
  });
});
