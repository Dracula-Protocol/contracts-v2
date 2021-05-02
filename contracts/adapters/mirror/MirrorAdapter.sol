// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./ILPPool.sol";

contract MirrorAdapter is BaseAdapter {
    ILPPool[] pools;
    address immutable MASTER_VAMPIRE;
    IERC20 constant MIR = IERC20(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
    IUniswapV2Pair constant MIR_WETH_PAIR = IUniswapV2Pair(0x57aB5AEB8baC2586A0d437163C3eb844246336CE);

    constructor(address _weth, address _factory, address _masterVampire)
        BaseAdapter(_weth, _factory)
    {
        pools.push(ILPPool(0x5d447Fc0F8965cED158BAB42414Af10139Edf0AF)); // MIR-UST
        pools.push(ILPPool(0x735659C8576d88A2Eb5C810415Ea51cB06931696)); // UST-mAAPL
        pools.push(ILPPool(0x5b64BB4f69c8C03250Ac560AaC4C7401d78A1c32)); // mGOOGL-UST
        pools.push(ILPPool(0x43DFb87a26BA812b0988eBdf44e3e341144722Ab)); // mTSLA-UST
        pools.push(ILPPool(0x29cF719d134c1C18daB61C2F4c0529C4895eCF44)); // UST-mNFLX
        pools.push(ILPPool(0xc1d2ca26A59E201814bF6aF633C3b3478180E91F)); // mQQQ-UST
        pools.push(ILPPool(0x99d737ab0df10cdC99c6f64D0384ACd5C03AEF7F)); // UST-mTWTR
        pools.push(ILPPool(0x27a14c03C364D3265e0788f536ad8d7afB0695F7)); // mMSFT-UST
        pools.push(ILPPool(0x1fABef2C2DAB77f01053E9600F70bE1F3F657F51)); // mAMZN-UST
        pools.push(ILPPool(0x769325E8498bF2C2c3cFd6464A60fA213f26afcc)); // mBABA-UST
        pools.push(ILPPool(0xE214a6ca22BE90f011f34FDddC7c5A07800F8BCd)); // mIAU-UST
        pools.push(ILPPool(0xDB278fb5f7d4A7C3b83F80D18198d872Bbf7b923)); // mSLV-UST
        pools.push(ILPPool(0x2221518288AF8c5D5a87fd32717fAb154240d942)); // mUSO-UST
        pools.push(ILPPool(0xBC07342D01fF5D72021Bb4cb95F07C252e575309)); // mVIXY-UST

    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return MIR;
    }

    function poolCount() external view override returns (uint256) {
        return pools.length;
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        MIR.transfer(address(MIR_WETH_PAIR), rewardAmount);
        (uint mirReserve, uint wethReserve,) = MIR_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, mirReserve, wethReserve);
        MIR_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        return pools[poolId].lpt();
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        return pools[poolId].lpt().balanceOf(user);
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return pools[victimPoolId].earned(MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(pools[poolId]), uint256(-1));
        ILPPool(adapter.poolAddress(poolId)).stake(amount);
        return 0;
    }

    function withdraw(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        ILPPool(adapter.poolAddress(poolId)).withdraw(amount);
        return 0;
    }

    function claimReward(address _adapter, uint256, uint256 victimPoolId) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        ILPPool(adapter.poolAddress(victimPoolId)).getReward();
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(pools[poolId]);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(MIR_WETH_PAIR);
    }

    function lockedValue(address, uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }

    function totalLockedValue(uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }

    function normalizedAPY(uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }
}
