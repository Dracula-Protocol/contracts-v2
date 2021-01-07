const fs = require('fs');

const DEPLOYER = '0x94627695F66Ab36Ae00c1995a30Bf5B30E139873';
const DRC_ADDRESS = '0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

async function deployMasterVampire(dracula_token, drain_distributor, drain_controller) {
  const MasterVampire = await ethers.getContractFactory("MasterVampire");

  const master_vampire = await MasterVampire.deploy(dracula_token.address,
                                                    drain_distributor.address,
                                                    drain_controller.address);
  await master_vampire.deployed();

  console.log(`MasterVampire deployed to: `, master_vampire.address);
  console.log(`MasterVampire deploy hash: `, master_vampire.deployTransaction.hash);

  await drain_controller.setMasterVampire(master_vampire.address);

  return master_vampire;
}

async function deployDrainDistributor(reward_pool, lp_controller) {
  const DrainController = await ethers.getContractFactory("DrainDistributor");

  const drain_distributor = await DrainDistributor.deploy(reward_pool.address, lp_controller.address);
  await drain_distributor.deployed();

  console.log(`DrainDistributor deployed to: `, drain_distributor.address);
  console.log(`DrainDistributor deploy hash: `, drain_distributor.deployTransaction.hash);

  await reward_pool.setRewardDistributor(drain_distributor.address);

  return drain_distributor;
}

async function deployDrainController(drain_distributor) {
  const DrainController = await ethers.getContractFactory("DrainController");

  const drain_controller = await DrainController.deploy(drain_distributor.address);
  await drain_controller.deployed();

  console.log(`DrainController deployed to: `, drain_controller.address);
  console.log(`DrainController deploy hash: `, drain_controller.deployTransaction.hash);

  await drain_distributor.changeDrainController(drain_controller.address);

  return drain_controller;
}

async function deployLPController() {
  const LiquidityController = await ethers.getContractFactory("LiquidityController");

  const liquidity_controller = await LiquidityController.deploy();
  await liquidity_controller.deployed();

  console.log(`LiquidityController deployed to: `, liquidity_controller.address);
  console.log(`LiquidityController deploy hash: `, liquidity_controller.deployTransaction.hash);

  return liquidity_controller;
}

async function deployRewardPool() {
  const RewardPool = await ethers.getContractFactory("RewardPool");

  const REWARD_DURATION = 604800; // 7 days

  const reward_pool = await RewardPool.deploy(WETH_ADDRESS, DRC_ADDRESS, REWARD_DURATION, DEPLOYER);
  await reward_pool.deployed();

  console.log(`RewardPool deployed to: `, reward_pool.address);
  console.log(`RewardPool deploy hash: `, reward_pool.deployTransaction.hash);

  return reward_pool;
}

async function main() {
  const dracula_token = await ethers.getContractAt('DraculaToken', DRC_ADDRESS);
  const liquidity_controller = await deployLPController();
  const reward_pool = await deployRewardPool();
  const drain_distributor = await deployDrainDistributor(reward_pool, liquidity_controller);
  const drain_controller = await deployDrainController(drain_distributor);
  const master_vampire = await deployMasterVampire(dracula_token, drain_distributor, drain_controller);
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});