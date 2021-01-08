import { expect } from 'chai'
import { Contract, constants, utils } from 'ethers'
const { waffle, ethers } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;

import StabilizeAdapter from '../artifacts/contracts/adapters/stabilize/StabilizeAdapter.sol/StabilizeAdapter.json';

describe('StabilizeAdapter', () => {
  const wallets = provider.getWallets();
  const [alice, bob, carol] = wallets;

  const UNI_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
  const STBZ = '0xB987D48Ed8f2C468D52D6405624EADBa5e76d723'

  it('can sell reward for weth', async () => {
    const weth = await ethers.getContractAt('IERC20', WETH);
    const stbz = await ethers.getContractAt('IERC20', STBZ);
    const stabilize_adapter = await deployContract(alice, StabilizeAdapter);

    expect(await stbz.balanceOf(alice.address)).to.eq(0);
    expect(await stbz.balanceOf(stabilize_adapter.address)).to.eq(0);
    expect(await weth.balanceOf(bob.address)).to.eq(0);

    const uniswap_router = await ethers.getContractAt('IUniswapV2Router02', UNI_ROUTER);
    await weth.approve(uniswap_router.address, constants.MaxUint256);
    await uniswap_router.swapExactETHForTokens(0, [WETH, STBZ], stabilize_adapter.address, constants.MaxUint256, {
      value: utils.parseEther('1')
    });

    expect(await stbz.balanceOf(stabilize_adapter.address)).to.gt(0);
    const stbz_balance = await stbz.balanceOf(stabilize_adapter.address);
    await stabilize_adapter.sellRewardForWeth(stabilize_adapter.address, stbz_balance, bob.address);
    expect(await weth.balanceOf(bob.address)).to.gt(utils.parseEther('0.9'));
    expect(await stbz.balanceOf(stabilize_adapter.address)).to.eq(0);
  });
});