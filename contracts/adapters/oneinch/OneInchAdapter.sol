// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IFarmRewards.sol";

contract OneInchAdapter is BaseAdapter {
    using SafeMath for uint256;

    address immutable MASTER_VAMPIRE;
    IERC20 constant ONEINCH = IERC20(0x111111111117dC0aa78b770fA6A738034120C302);
    IFarmRewards constant ONEINCH_MASTER_POOL = IFarmRewards(0x0EF1B8a0E726Fc3948E15b23993015eB1627f210);
    IUniswapV2Pair constant ONEINCH_WETH_PAIR = IUniswapV2Pair(0x26aAd2da94C59524ac0D93F6D6Cbf9071d7086f2);
    IFarmRewards[] pools;

    constructor(address _weth, address _factory, address _masterVampire)
        BaseAdapter(_weth, _factory)
    {
        MASTER_VAMPIRE = _masterVampire;
        pools.push(IFarmRewards(0xE65184b402376703Adc27A7d7e0e8D35A264A240)); // 1INCH-ETH Pool
        pools.push(IFarmRewards(0x1055f60Bbf27D233C4E34D2E03e35567427415Fa)); // 1INCH-USDC pool
        pools.push(IFarmRewards(0x73f5E5260423A2742d9F8Ac49DeA6CB5eaec465e)); // 1INCH-WBTC pool
        pools.push(IFarmRewards(0x8b1aF1298f5c0CA8a6B4E66626a4bDaE0f7521e5)); // 1INCH-VSP pool
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return ONEINCH;
    }

    function poolCount() external view override returns (uint256) {
        return pools.length;
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns (uint256) {
        ONEINCH.transfer(address(ONEINCH_WETH_PAIR), rewardAmount);
        (uint oneinchReserve, uint wethReserve,) = ONEINCH_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, oneinchReserve, wethReserve);
        ONEINCH_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        return IERC20(address(pools[poolId]));
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        return pools[poolId].balanceOf(user);
    }

    function pendingReward(address _adapter, uint256, uint256 victimPoolId) external view override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IFarmRewards pool = IFarmRewards(adapter.poolAddress(victimPoolId));
        return pool.earned(0, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(pools[poolId]), uint256(-1));
        pools[poolId].stake(amount);
        return 0;
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        pools[poolId].withdraw(amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        pools[victimPoolId].getReward(0);
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(pools[poolId]);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(ONEINCH_WETH_PAIR);
    }

    function lockedValue(address, uint256) external pure override returns (uint256) {
        require(false, "not implemented");
        return 0;
    }

    function totalLockedValue(uint256) external pure override returns (uint256) {
        require(false, "not implemented");
        return 0;
    }

    function normalizedAPY(uint256) external pure override returns (uint256) {
        require(false, "not implemented");
        return 0;
    }
}
