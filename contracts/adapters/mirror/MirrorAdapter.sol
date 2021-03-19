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
    IERC20 constant MIR = IERC20(0x09a3ecafa817268f77be1283176b946c4ff2e608);
    IUniswapV2Pair constant MIR_WETH_PAIR = IUniswapV2Pair(0x57ab5aeb8bac2586a0d437163c3eb844246336ce);

    constructor() {
        pools.push(ILPPool(0x87da823b6fc8eb8575a235a824690fda94674c88)); // MIR-UST
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
        return pools[poolId].lpt;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        return pools[poolId].lpt.balanceOf(user);
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return pools[victimPoolId].earned(MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken.approve(address(pools[poolId]), uint256(-1));
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

    function emergencyWithdraw(address, uint256 poolId) external override {
        require(false, "not implemented");
        return 0;
        }

    // Service methods
    function poolAddress(uint256 poolId) external pure override returns (address) {
        return address(pools[poolId]);
    }

    function rewardToWethPool() external pure override returns (address) {
        require(false, "not implemented");
        return 0;
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
