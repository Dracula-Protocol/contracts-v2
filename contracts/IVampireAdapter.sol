// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVampireAdapter {
    // Victim info
    function rewardToken(uint256 poolId) external view returns (IERC20);
    function rewardValue(uint256 poolId, uint256 amount) external view returns(uint256);
    function poolCount() external view returns (uint256);
    function sellableRewardAmount(uint256 poolId) external view returns (uint256);

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address adapter, uint256 poolId, uint256 rewardAmount, address to) external returns(uint256);

    // Pool info
    function lockableToken(uint256 poolId) external view returns (IERC20);
    function lockedAmount(address user, uint256 poolId) external view returns (uint256);
    function pendingReward(address adapter, uint256 poolId, uint256 victimPoolId) external view returns (uint256);

    // Pool actions, requires impersonation via delegatecall
    function deposit(address adapter, uint256 poolId, uint256 amount) external returns (uint256);
    function withdraw(address adapter, uint256 poolId, uint256 amount) external returns (uint256);
    function claimReward(address adapter, uint256 poolId, uint256 victimPoolId) external;

    function emergencyWithdraw(address adapter, uint256 poolId) external;

    // Service methods
    function poolAddress(uint256 poolId) external view returns (address);
    function rewardToWethPool() external view returns (address);

    // Governance info methods
    function lockedValue(address user, uint256 poolId) external view returns (uint256);
    function totalLockedValue(uint256 poolId) external view returns (uint256);
    function normalizedAPY(uint256 poolId) external view returns (uint256);
}
