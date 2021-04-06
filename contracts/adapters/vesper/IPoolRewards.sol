// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVesperPool {
    function notifyRewardAmount(uint256) external;
    function claimReward(address) external;
    function updateReward(address) external;
    function rewardForDuration() external view returns (uint256);
    function claimable(address) external view returns (uint256);
    function pool() external view returns (address);
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
}
