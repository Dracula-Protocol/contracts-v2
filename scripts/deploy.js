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

  const IBVEth = await ethers.getContractFactory("IBVEth");
  const ibveth = await IBVEth.deploy();
  const master_vampire = await MasterVampire.deploy(drain_distributor.address,
                                                    drain_controller.address,
                                                    ibveth.address);
  await master_vampire.deployed();

  console.log(' MasterVampire deployed to: ', master_vampire.address);
  console.log(' MasterVampire deploy hash: ', master_vampire.deployTransaction.hash);

  await drain_controller.setMasterVampire(master_vampire.address);

  return master_vampire;
}

async function deployDrainDistributor(uni_lp_reward_pool, yfl_lp_reward_pool, drc_reward_pool) {
  console.log("* Deploying DrainDistributor");
  const DrainDistributor = await ethers.getContractFactory("DrainDistributor");

  const drain_distributor = await DrainDistributor.deploy(uni_lp_reward_pool.address,
                                                          yfl_lp_reward_pool.address,
                                                          drc_reward_pool.address);
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

  const DODO = await ethers.getContractFactory("DODOAdapter");
  const dodo = await DODO.deploy();
  await dodo.deployed();

  console.log(' DODO deployed to: ', dodo.address);
  console.log(' DODO deploy hash: ', dodo.deployTransaction.hash);

  const Pickle = await ethers.getContractFactory("PickleAdapter");
  const pickle = await Pickle.deploy();
  await pickle.deployed();

  console.log(' Pickle deployed to: ', pickle.address);
  console.log(' Pickle deploy hash: ', pickle.deployTransaction.hash);

  const Stabilize = await ethers.getContractFactory("StabilizeAdapter");
  const stabilize = await Stabilize.deploy();
  await stabilize.deployed();

  console.log(' Stabilize deployed to: ', stabilize.address);
  console.log(' Stabilize deploy hash: ', stabilize.deployTransaction.hash);

  const Sushi = await ethers.getContractFactory("SushiAdapter");
  const sushi = await Sushi.deploy();
  await sushi.deployed();

  console.log(' Sushi deployed to: ', sushi.address);
  console.log(' Sushi deploy hash: ', sushi.deployTransaction.hash);

  const TruFi = await ethers.getContractFactory("TruefiAdapter");
  const truefi = await TruFi.deploy();
  await truefi.deployed();

  console.log(' TruFi deployed to: ', truefi.address);
  console.log(' TruFi deploy hash: ', truefi.deployTransaction.hash);

  const YAX = await ethers.getContractFactory("YAxisAdapter");
  const yax = await YAX.deploy();
  await yax.deployed();

  console.log(' YAX deployed to: ', yax.address);
  console.log(' YAX deploy hash: ', yax.deployTransaction.hash);

  // TODO
  // Update MV address in all adapters

  return {dodo, pickle, stabilize, sushi, truefi, yax};
}

async function initVictimPools(master_vampire, pools, victim_address, victim_name) {
  console.log("* Init Victim Pools");
  const USE_CHI = 0;
  async function addPool(master_vampire, victim_address, victim_pid, weth_drain_modifier, use_chi) {
    await master_vampire.add(victim_address, victim_pid, weth_drain_modifier, use_chi);
    console.log('   Added PID: ', victim_pid);
  }

  console.log(' Adding pools for: ', victim_name)
  console.log('   Victim address: ', victim_address)
  for (let pool of pools) {
    await addPool(master_vampire, victim_address, pool.pid, '150', USE_CHI);
  }
}

async function main() {
  const network = await ethers.provider.getNetwork();
  const CHAIN_ID = network.chainId;
  console.log("Deploying to chain: ", CHAIN_ID);

  const vampire_adapter = await deployVampireAdapter();
  const {uni_lp_reward_pool, yfl_lp_reward_pool, drc_reward_pool} = await deployRewardPools();
  const drain_distributor = await deployDrainDistributor(uni_lp_reward_pool,
                                                         yfl_lp_reward_pool,
                                                         drc_reward_pool);

  const drain_controller = await deployDrainController(vampire_adapter, drain_distributor);
  const master_vampire = await deployMasterVampire(vampire_adapter, drain_distributor, drain_controller);

  // Temp workaround for HH bug
  //const master_vampire2 = await deployMasterVampire(vampire_adapter, drain_distributor, drain_controller);

  const {
    dodoPIDs,
    picklePIDs,
    sushiPIDs,
    luaPIDs,
    stabilizePIDs,
    yaxisPIDs } = require('./pools');

  const {dodo, pickle, stabilize, sushi, truefi, yax} = await deployAdapters();
  await initVictimPools(master_vampire, dodoPIDs, dodo.address, 'DODO');
  await initVictimPools(master_vampire, picklePIDs, pickle.address, 'Pickle');
  await initVictimPools(master_vampire, sushiPIDs, sushi.address, 'Sushi');
  await initVictimPools(master_vampire, stabilizePIDs, sushi.address, 'Stabilize');
  await initVictimPools(master_vampire, yaxisPIDs, sushi.address, 'yAxis');
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});