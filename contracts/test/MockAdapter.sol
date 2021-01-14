// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../libraries/UniswapV2Library.sol";
import "../IVampireAdapter.sol";
import "./ERC20Mock.sol";
import "./IMockMasterChef.sol";

import "hardhat/console.sol";

contract MockAdapter is IVampireAdapter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Pair constant tusdWethPair = IUniswapV2Pair(0xb4d0d9df2738abE81b87b66c80851292492D1404);
    IERC20 constant tusd = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);

    // Note: these are dynamic and must be set to the deployed contracts from the unit tests
    IMockMasterChef constant mockChef = IMockMasterChef(0x8464135c8F25Da09e49BC8782676a84730C318bC);
    address constant masterVampire = 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318;

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return tusd;
    }

    function poolCount() external view override returns (uint256) {
        return mockChef.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        tusd.safeTransfer(address(tusdWethPair), rewardAmount);
        (uint tusdReserve, uint wethReserve,) = tusdWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, tusdReserve, wethReserve);
        tusdWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
   function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = mockChef.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = mockChef.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return mockChef.pendingMock(poolId, masterVampire);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(mockChef), uint256(-1));
        mockChef.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        mockChef.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        mockChef.deposit(poolId, 0);
    }

    function emergencyWithdraw(address _adapter, uint256 poolId) external override {
        mockChef.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(this);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(tusdWethPair);
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
