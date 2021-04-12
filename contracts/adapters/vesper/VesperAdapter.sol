// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "../../IMasterVampire.sol";
import "./IVesperController.sol";
import "./IVesperPool.sol";
import "./IPoolRewards.sol";

contract VesperAdapter is BaseAdapter {
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IUniswapV2Pair constant VSP_WETH_PAIR = IUniswapV2Pair(0x6D7B6DaD6abeD1DFA5eBa37a6667bA9DCFD49077);
    IERC20 constant VSP = IERC20(0x1b40183EFB4Dd766f11bDa7A7c3AD8982e998421);
    IVesperPool[] pools;

    constructor(address _weth, address _factory)
        BaseAdapter(_weth, _factory)
    {
        pools.push(IVesperPool(0x103cc17C2B1586e5Cd9BaD308690bCd0BBe54D5e)); // VETH pool
        pools.push(IVesperPool(0x4B2e76EbBc9f2923d83F5FBDe695D8733db1a17B)); // VWBTC pool
        pools.push(IVesperPool(0x0C49066C0808Ee8c673553B7cbd99BCC9ABf113d)); // VUSDC pool
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return VSP;
    }

    function poolCount() external pure override returns (uint256) {
        return uint256(3);
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        VSP.transfer(address(VSP_WETH_PAIR), rewardAmount);
        (uint vspReserve, uint wethReserve,) = VSP_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, vspReserve, wethReserve);
        VSP_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function pendingReward(address _adapter, uint256, uint256 victimPoolId) external view override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IVesperPool pool = IVesperPool(adapter.poolAddress(victimPoolId));
        IVesperController controller = IVesperController(pool.controller());
        IPoolRewards poolRewards = IPoolRewards(controller.poolRewards(adapter.poolAddress(victimPoolId)));
        return poolRewards.claimable(MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(pools[poolId]), uint256(-1));
        IVesperPool(adapter.poolAddress(poolId)).deposit(amount);
        return 0;
    }

    function withdraw(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IVesperPool(adapter.poolAddress(poolId)).withdraw(amount);
        return 0;
    }

    function claimReward(address _adapter, uint256, uint256 victimPoolId) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IVesperPool pool = IVesperPool(adapter.poolAddress(victimPoolId));
        IVesperController controller = IVesperController(pool.controller());
        IPoolRewards poolRewards = IPoolRewards(controller.poolRewards(adapter.poolAddress(victimPoolId)));
        return poolRewards.claimReward(MASTER_VAMPIRE);
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(pools[poolId]);
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        return pools[poolId].balanceOf(user);
    }

    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        return pools[poolId].token();
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(VSP_WETH_PAIR);
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