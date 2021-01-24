// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITrueFarm {
    function stakingToken() external view returns (IERC20);
    function trustToken() external view returns (IERC20);
    function totalStaked() external view returns (uint256);
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claim() external;
    function exit(uint256 amount) external;
    function staked(address account) external view returns (uint256);
    function claimableReward(address account) external view returns (uint256);
}
