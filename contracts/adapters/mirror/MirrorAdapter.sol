// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./ILPPool.sol";

contract MirrorAdapter is BaseAdapter {
    ILPPool[] pools;
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IERC20 constant MIR = IERC20(0x09a3EcAFa817268f77BE1283176B946C4ff2E608);
    IUniswapV2Pair constant MIR_WETH_PAIR = IUniswapV2Pair(0x57aB5AEB8baC2586A0d437163C3eb844246336CE);

    constructor(address _weth, address _factory)
        BaseAdapter(_weth, _factory)
    {
        pools.push(ILPPool(0x87dA823B6fC8EB8575a235A824690fda94674c88)); // MIR-UST
        pools.push(ILPPool(0xB022e08aDc8bA2dE6bA4fECb59C6D502f66e953B)); // UST-mAAPL
        pools.push(ILPPool(0x4b70ccD1Cf9905BE1FaEd025EADbD3Ab124efe9a)); // mGOOGL-UST
        pools.push(ILPPool(0x5233349957586A8207c52693A959483F9aeAA50C)); // mTSLA-UST
        pools.push(ILPPool(0xC99A74145682C4b4A6e9fa55d559eb49A6884F75)); // UST-mNFLX
        pools.push(ILPPool(0x34856be886A2dBa5F7c38c4df7FD86869aB08040)); // UST-mTWTR
        pools.push(ILPPool(0x0Ae8cB1f57e3b1b7f4f5048743710084AA69E796)); // mAMZN-UST
        pools.push(ILPPool(0x676Ce85f66aDB8D7b8323AeEfe17087A3b8CB363)); // mBABA-UST
        pools.push(ILPPool(0xd7f97aa0317C08A1F5C2732e7894933f11724868)); // mIAU-UST
        pools.push(ILPPool(0x860425bE6ad1345DC7a3e287faCBF32B18bc4fAe)); // mSLV-UST
        pools.push(ILPPool(0x6Bd8Ca9D141aa95842b41e1431A244C309c9008C)); // mUSO-UST
        pools.push(ILPPool(0x6094367ea57ff4f545e2672e024393d82a1d3F28)); // mVIXY-UST
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
        return;
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
