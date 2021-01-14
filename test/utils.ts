import { providers, BigNumber } from 'ethers';
import { network, ethers } from 'hardhat';

export async function evmSnapshot(): Promise<string> {
  const data = await network.provider.request({
    method: "evm_snapshot",
    params: []
  });
  return String(data);
};

export async function evmRevert(snapshot_id: string) {
  await network.provider.request({
    method: "evm_revert",
    params: [snapshot_id]
  });
};

export async function latestBlock() {
  const block = await ethers.provider.getBlockNumber();
  return BigNumber.from(block);
};

// Returns the time of the last mined block in seconds
export async function latestBlockTimestamp() {
  const block_number = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(block_number);
  if (block) {
    return BigNumber.from(block.timestamp);
  }
  console.log('WARN: latestBlockTimestamp: failed to get block #', block_number.toString());
  return BigNumber.from(0);
};

export async function advanceBlocks(count: number): Promise<void> {
  if (count < 1) {
    throw new Error("No blocks to mine");
  }

  for (let i = 0; i < count; i++) {
    await network.provider.request({
      method: "evm_mine",
      params: []
    });
  }
};


export async function advanceBlock() {
  await network.provider.request({
    method: "evm_mine",
    params: []
  });
};

// Advance the block to the target height
export async function advanceBlockTo(target: any): Promise<void> {
  target = BigNumber.from(target);
  const currentBlock = (await latestBlock());
  const start = Date.now();
  let notified;
  if (target.lt(currentBlock)) throw Error(`Target block #(${target}) is lower than current block #(${currentBlock})`);
  while ((await latestBlock()).lt(target)) {
    if (!notified && Date.now() - start >= 5000) {
      notified = true;
      console.log('WARN: advanceBlockTo: Advancing too many blocks is causing this test to be slow.');
    }
    await advanceBlock();
  }
};

export async function advanceBlockAndTime(time: number) {
  const current_block_time = (await latestBlockTimestamp()).toNumber();
  const forward_time = current_block_time + time;
  await network.provider.request({
    method: "evm_mine",
    params: []
  });
  await network.provider.request({
    method: "evm_increaseTime",
    params: [forward_time]
  });
};

export const duration = {
  seconds: function (val: any) { return BigNumber.from(val); },
  minutes: function (val: any) { return BigNumber.from(val).mul(this.seconds('60')); },
  hours: function (val: any) { return BigNumber.from(val).mul(this.minutes('60')); },
  days: function (val: any) { return BigNumber.from(val).mul(this.hours('24')); },
  weeks: function (val: any) { return BigNumber.from(val).mul(this.days('7')); },
  years: function (val: any) { return BigNumber.from(val).mul(this.days('365')); },
};
