// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../libraries/UniswapV2Library.sol";
import "../BaseAdapter.sol";
import "./ERC20Mock.sol";
import "./IMockMasterChef.sol";

import "hardhat/console.sol";

contract MockAdapter is BaseAdapter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Pair constant tusdWethPair = IUniswapV2Pair(0xb4d0d9df2738abE81b87b66c80851292492D1404);
    IERC20 constant tusd = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);

    IMockMasterChef immutable mockChef;
    address immutable masterVampire;

    constructor(address _masterVampire, address _mockChef) public {
        masterVampire = _masterVampire;
        mockChef = IMockMasterChef(_mockChef);
    }

    // Victim info
    function rewardToken(uint256) public view override returns (IERC20) {
        return tusd;
    }

    function poolCount() external view override returns (uint256) {
        return mockChef.poolLength();
    }

    function sellableRewardAmount(uint256) external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
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

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return mockChef.pendingMock(victimPoolId, masterVampire);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(mockChef), uint256(-1));
        mockChef.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        mockChef.withdraw(poolId, amount);
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        mockChef.deposit(victimPoolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        mockChef.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
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
