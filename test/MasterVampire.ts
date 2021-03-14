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

describe('MasterVampire', () => {

  let deployer:SignerWithAddress,
      alice:SignerWithAddress,
      bob:SignerWithAddress,
      carol:SignerWithAddress,
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

  it('early withdrawal penalty works', async () => {

    await mockLP.mint(alice.address, utils.parseEther('3000'));

    // Deposit the Mock LP into the Mock Adapter pool
    await mockLP.connect(alice).approve(masterVampire.address, utils.parseEther('1000'));

    await masterVampire.updateWithdrawPenalty('500'); // 50% penalty
    await masterVampire.connect(alice).deposit(0, utils.parseEther('1000'), 0);

    // Cool off time should be 24 hours after deposit
    const user_info = await masterVampire.userInfo(0, alice.address);
    let current_block_time = await latestBlockTimestamp();
    expect(user_info.coolOffTime).to.gte(current_block_time);
    expect(user_info.coolOffTime).to.gte(current_block_time.add(duration.hours(23)));

    await advanceBlocks(200);
    await drainController.whitelist(carol.address);

    const drainable = await drainController.isDrainable();
    expect(drainable.length).to.gt(0);
    await drainController.connect(carol).optimalMassDrain(drainable);

    // Withdrawing before cool off incurs penalty
    let alice_eth_balance_before = await alice.getBalance();
    let tx = await masterVampire.pendingWethReal(0, alice.address);
    let tx_receipt = await tx.wait();

    let pending_weth = tx_receipt.events[0].args.amount;
    await masterVampire.connect(alice).withdraw(0, utils.parseEther('1000'), 0);
    expect(BigNumber.from(alice_eth_balance_before).sub(pending_weth)).to.lt(BigNumber.from(await alice.getBalance()).sub(pending_weth));

    // Withdrawing after cool off incurs NO penalty
    await mockLP.connect(alice).approve(masterVampire.address, utils.parseEther('1000'));
    await masterVampire.connect(alice).deposit(0, utils.parseEther('1000'), 0);
    await advanceBlocks(5);
    await advanceBlockAndTime(current_block_time.add(duration.hours(24)).toNumber());

    alice_eth_balance_before = await alice.getBalance();
    tx = await masterVampire.pendingWethReal(0, alice.address);
    tx_receipt = await tx.wait();
    pending_weth = tx_receipt.events[0].args.amount;

    await masterVampire.connect(alice).withdraw(0, utils.parseEther('1000'), 0);
    // Balance must be greater than previous balance + pending reward - gas
    expect(await alice.getBalance()).to.gte(BigNumber.from(alice_eth_balance_before).add(BigNumber.from(pending_weth).div(2)));
  });


  describe('mock adapter should work with mastervampire', () => {
    it('rari capital ibeth strategy', async () => {
      // Deposit the Mock LP into the Mock Adapter pool
      await mockLP.mint(alice.address, utils.parseEther('1000'));
      await mockLP.connect(alice).approve(masterVampire.address, utils.parseEther('1000'));
      await masterVampire.connect(alice).deposit(0, utils.parseEther('1000'), 0);

      // Advanced blocks
      await advanceBlocks(10);

      // Expect to have 10 MOCK (10 blocks/1 per block)
      expect((await mockMasterChef.pendingMock(0, masterVampire.address)).valueOf()).to.eq(utils.parseEther('10'));
      /*console.log("Pending reward (alice): ", utils.formatEther((await mockMasterChef.pendingMock(0, masterVampire.address)).toString()));

      console.log("Before Drain:");
      console.log("      WETH Balance (MasterVampire): ", (await weth.balanceOf(masterVampire.address)).toString());
      console.log("  WETH Balance (MockMasterVampire): ", (await weth.balanceOf(masterVampire.address)).toString());
      console.log("               ETH Balance (Carol):", utils.formatEther(await carol.getBalance()).toString());*/

      await drainController.whitelist(carol.address);

      const drainable = await drainController.isDrainable();
      expect(drainable.length).to.gt(0);
      await drainController.connect(carol).optimalMassDrain(drainable);

      await drainDistributor.setWETHThreshold(utils.parseEther('0.01'));
      await drainDistributor.distribute();

      const StrategyRari = await deployments.get('StrategyRari');
      const strategyRari = await ethers.getContractAt('IBVEthRari', StrategyRari.address, deployer);
      const ibToken = await ethers.getContractAt('IERC20', await strategyRari.ibToken(), deployer);

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
      let last_pending_weth = BigNumber.from(0);
      for (let b = 0; b < 10; b++) {
        //console.log("  Pending IBEth reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
        const tx = await masterVampire.pendingWethReal(0, alice.address);
        const tx_receipt = await tx.wait();
        let pending_weth = tx_receipt.events[0].args.amount;
        expect(pending_weth).to.gt(last_pending_weth);
        //console.log("  Pending WETH reward (alice): ", utils.formatEther(pending_weth.toString()))
        await advanceBlock();
      }

      for (let b = 0; b < 200; b++) {
        await advanceBlock();
      }

      const ethBeforeClaim = await alice.getBalance();
      //console.log("Before Claim:");
      //console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      //console.log("  ETH Balance (Alice):", utils.formatEther(await alice.getBalance()).toString());
      await masterVampire.connect(alice).claim(0, 0);
      //console.log("After Claim:");
      //console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      //console.log("  ETH Balance (Alice):", utils.formatEther(await alice.getBalance()).toString());
      expect(await alice.getBalance()).to.gt(ethBeforeClaim);

      for (let b = 0; b < 300; b++) {
        await advanceBlock();
      }

      expect(await drc.balanceOf(alice.address)).to.eq(0);
      //console.log("Before Claim (DRC):");
      //console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      //console.log("  DRC Balance (Alice):", utils.formatEther(await drc.balanceOf(alice.address)).toString());
      await masterVampire.connect(alice).claim(0, parseInt("0x2"));
      //console.log("After Claim (DRC):");
      //console.log("  Pending reward (alice): ", utils.formatEther((await masterVampire.pendingWeth(0, alice.address)).toString()));
      //console.log("  DRC Balance (Alice):", utils.formatEther(await drc.balanceOf(alice.address)).toString());
      expect(await drc.balanceOf(alice.address)).to.gt(0);
    });
  });
});