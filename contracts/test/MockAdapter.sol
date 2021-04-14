// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../libraries/UniswapV2Library.sol";
import "../BaseAdapter.sol";
import "./MockERC20.sol";
import "./IMockMasterChef.sol";
import "./MockUniswapRouter.sol";
import "./MockUniswapFactory.sol";

contract MockAdapter is BaseAdapter {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Pair immutable rewardWethPair;
    IERC20 immutable reward;
    IUniswapRouter immutable router;

    IMockMasterChef immutable mockChef;
    address immutable masterVampire;

    constructor(address _masterVampire, address _mockChef, address _rewardToken, address _weth, address _router, address _factory)
        BaseAdapter(_weth, _factory)
    {
        masterVampire = _masterVampire;
        mockChef = IMockMasterChef(_mockChef);
        reward = IERC20(_rewardToken);
        rewardWethPair = IUniswapV2Pair(MockUniswapFactory(_factory).getPair(address(_rewardToken), address(_weth)));
        router = IUniswapRouter(_router);
    }

    // Victim info
    function rewardToken(uint256) public view override returns (IERC20) {
        return reward;
    }

    function poolCount() external view override returns (uint256) {
        return mockChef.poolLength();
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        reward.transfer(address(rewardWethPair), rewardAmount);
        (uint mirReserve, uint wethReserve,) = rewardWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, mirReserve, wethReserve);
        rewardWethPair.swap(uint(0), amountOutput, to, new bytes(0));
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
        return 0;
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        mockChef.withdraw(poolId, amount);
        return 0;
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
        return address(rewardWethPair);
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
