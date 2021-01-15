// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "./IValueMinorPool.sol";

contract YfvAdapter is IVampireAdapter {
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IValueMinorPool constant valueMinorPool = IValueMinorPool(0xcC51169c21158084371C63BC260abA4AfdcfBd2f);
    IERC20 constant value = IERC20(0x49E833337ECe7aFE375e44F4E3e8481029218E5c);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant valueWethPair = IUniswapV2Pair(0xd9159376499936868A5B061a4633481131e70732);
    // token 0 -  value
    // token 1 - weth

    // Victim info
    function rewardToken(uint256) external view override returns (IERC20) {
        return value;
    }

    function poolCount() external view override returns (uint256) {
        return valueMinorPool.poolLength();
    }

    function sellableRewardAmount(uint256) external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        value.transfer(address(valueWethPair), rewardAmount);
        (uint valueReserve, uint wethReserve,) = valueWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, valueReserve, wethReserve);
        valueWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,,) = valueMinorPool.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,,) = valueMinorPool.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return valueMinorPool.pendingValue(poolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(valueMinorPool), uint256(-1));
        valueMinorPool.deposit(poolId, amount, address(0));
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        valueMinorPool.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        valueMinorPool.deposit(poolId, 0, address(0));
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        valueMinorPool.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(valueMinorPool);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(valueWethPair);
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