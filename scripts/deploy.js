const fs = require('fs');

const DEPLOYER = '0x94627695F66Ab36Ae00c1995a30Bf5B30E139873';
const DRC_ADDRESS = '0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

async function deployVampireAdapter() {
  console.log("* Deploying VampireAdapter");
  const VALib = await ethers.getContractFactory("VampireAdapter");
  const vampire_adapter = await VALib.deploy();
  await vampire_adapter.deployed();

  console.log(' VampireAdapter deployed to: ', vampire_adapter.address);
  console.log(' VampireAdapter deploy hash: ', vampire_adapter.deployTransaction.hash);

  return vampire_adapter;
}

async function deployMasterVampire(vampire_adapter, drain_distributor, drain_controller) {
  console.log("* Deploying MasterVampire");
  const MasterVampire = await ethers.getContractFactory("MasterVampire", {
    libraries: {
      VampireAdapter: vampire_adapter.address
    }
  });

  const master_vampire = await MasterVampire.deploy(drain_distributor.address,
                                                    drain_controller.address);
  await master_vampire.deployed();

  console.log(' MasterVampire deployed to: ', master_vampire.address);
  console.log(' MasterVampire deploy hash: ', master_vampire.deployTransaction.hash);

  await drain_controller.setMasterVampire(master_vampire.address);

  return master_vampire;
}

async function deployDrainDistributor(uni_lp_reward_pool, yfl_lp_reward_pool, drc_reward_pool, lp_controller) {
  console.log("* Deploying DrainDistributor");
  const DrainDistributor = await ethers.getContractFactory("DrainDistributor");

  const drain_distributor = await DrainDistributor.deploy(uni_lp_reward_pool.address,
                                                          yfl_lp_reward_pool.address,
                                                          drc_reward_pool.address,
                                                          lp_controller.address);
  await drain_distributor.deployed();

  console.log(' DrainDistributor deployed to: ', drain_distributor.address);
  console.log(' DrainDistributor deploy hash: ', drain_distributor.deployTransaction.hash);

  await uni_lp_reward_pool.addRewardSupplier(drain_distributor.address);
  await yfl_lp_reward_pool.addRewardSupplier(drain_distributor.address);
  await drc_reward_pool.addRewardSupplier(drain_distributor.address);

  return drain_distributor;
}

async function deployDrainController(vampire_adapter, drain_distributor) {
  console.log("* Deploying DrainController");
  const DrainController = await ethers.getContractFactory("DrainController", {
    libraries: {
      VampireAdapter: vampire_adapter.address
    }
  });

  const drain_controller = await DrainController.deploy();
  await drain_controller.deployed();

  console.log(' DrainController deployed to: ', drain_controller.address);
  console.log(' DrainController deploy hash: ', drain_controller.deployTransaction.hash);

  await drain_distributor.changeDrainController(drain_controller.address);

  return drain_controller;
}

async function deployLPController() {
  console.log("* Deploying LiquidityController");
  const LiquidityController = await ethers.getContractFactory("LiquidityController");

  const liquidity_controller = await LiquidityController.deploy();
  await liquidity_controller.deployed();

  console.log(' LiquidityController deployed to: ', liquidity_controller.address);
  console.log(' LiquidityController deploy hash: ', liquidity_controller.deployTransaction.hash);

  return liquidity_controller;
}

async function deployRewardPools() {
  console.log("* Deploying Reward Pools");
  const RewardPool = await ethers.getContractFactory("RewardPool");
  const DRCRewardPool = await ethers.getContractFactory("DRCRewardPool");

  const REWARD_DURATION = 604800; // 7 days

  const UNI_DRC_ETH_ADDRESS = '0x276E62C70e0B540262491199Bc1206087f523AF6';
  const YFL_DRC_ETH_ADDRESS = '0xcEf225FE69B9B9c26c12f615581d4f77F44ECd2d';

  const uni_lp_reward_pool = await RewardPool.deploy(WETH_ADDRESS, UNI_DRC_ETH_ADDRESS, REWARD_DURATION, DEPLOYER);
  await uni_lp_reward_pool.deployed();

  console.log(' UNI LP RewardPool deployed to: ', uni_lp_reward_pool.address);
  console.log(' UNI LP RewardPool deploy hash: ', uni_lp_reward_pool.deployTransaction.hash);

  const yfl_lp_reward_pool = await RewardPool.deploy(WETH_ADDRESS, YFL_DRC_ETH_ADDRESS, REWARD_DURATION, DEPLOYER);
  await yfl_lp_reward_pool.deployed();

  console.log(' YFL LP RewardPool deployed to: ', yfl_lp_reward_pool.address);
  console.log(' YFL LP RewardPool deploy hash: ', yfl_lp_reward_pool.deployTransaction.hash);

  const drc_reward_pool = await DRCRewardPool.deploy(WETH_ADDRESS, DRC_ADDRESS, REWARD_DURATION, DEPLOYER);
  await drc_reward_pool.deployed();

  console.log(' DRC RewardPool deployed to: ', drc_reward_pool.address);
  console.log(' DRC RewardPool deploy hash: ', drc_reward_pool.deployTransaction.hash);

  return {uni_lp_reward_pool, yfl_lp_reward_pool, drc_reward_pool};
}

async function deployTimelock() {
  console.log("* Deploying Timelock");
  const Timelock = await ethers.getContractFactory("Timelock");
  const timelock = await Timelock.deploy(DEPLOYER, 43200);
  await timelock.deployed();

  console.log(' Timelock deployed to: ', timelock.address);
  console.log(' Timelock deploy hash: ', timelock.deployTransaction.hash);
}

async function deployAdapters() {
  console.log("* Deploying Adapters");
  // TODO
  // Update MV address in all adapters
}

async function main() {
  const network = await ethers.provider.getNetwork();
  const CHAIN_ID = network.chainId;
  console.log("Deploying to chain: ", CHAIN_ID);

  const vampire_adapter= await deployVampireAdapter();
  const liquidity_controller = await deployLPController();
  const {uni_lp_reward_pool, yfl_lp_reward_pool, drc_reward_pool} = await deployRewardPools();
  const drain_distributor = await deployDrainDistributor(uni_lp_reward_pool,
                                                         yfl_lp_reward_pool,
                                                         drc_reward_pool,
                                                         liquidity_controller);

  const drain_controller = await deployDrainController(vampire_adapter, drain_distributor);
  const master_vampire = await deployMasterVampire(vampire_adapter, drain_distributor, drain_controller);
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});