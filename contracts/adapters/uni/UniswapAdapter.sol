// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "./IUniswapPool.sol";

contract UniswapAdapter is IVampireAdapter {
    IUniswapPool[] pools;
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IERC20 constant uni = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant uniWethPair = IUniswapV2Pair(0xd3d2E2692501A5c9Ca623199D38826e513033a17);
    // token 0 - uni
    // token 1 - weth

    constructor() public {
        pools.push(IUniswapPool(0x6C3e4cb2E96B01F4b866965A91ed4437839A121a));
        pools.push(IUniswapPool(0x7FBa4B8Dc5E7616e59622806932DBea72537A56b));
        pools.push(IUniswapPool(0xa1484C3aa22a66C62b77E0AE78E15258bd0cB711));
        pools.push(IUniswapPool(0xCA35e32e7926b96A9988f61d510E038108d8068e));
    }

    // Victim info
    function rewardToken(uint256) external view override returns (IERC20) {
        return uni;
    }

    function poolCount() external view override returns (uint256) {
        return pools.length;
    }

    function sellableRewardAmount(uint256) external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        uni.transfer(address(uniWethPair), rewardAmount);
        (uint uniReserve, uint wethReserve,) = uniWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, uniReserve, wethReserve);
        uniWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        return pools[poolId].stakingToken();
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        return pools[poolId].balanceOf(user);
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return pools[poolId].earned(MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(adapter.poolAddress(poolId), uint256(-1));
        IUniswapPool(adapter.poolAddress(poolId)).stake(amount);
    }

    function withdraw(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IUniswapPool(adapter.poolAddress(poolId)).withdraw(amount);
    }

    function claimReward(address _adapter, uint256 poolId) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IUniswapPool(adapter.poolAddress(poolId)).getReward();
    }

    function emergencyWithdraw(address _adapter, uint256 poolId) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IUniswapPool(adapter.poolAddress(poolId)).withdraw(IUniswapPool(adapter.poolAddress(poolId)).balanceOf(address(this)));
    }
    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(pools[poolId]);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(uniWethPair);
    }

    function lockedValue(address, uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }

    function totalLockedValue(uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }

    function normalizedAPY(uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }
}
