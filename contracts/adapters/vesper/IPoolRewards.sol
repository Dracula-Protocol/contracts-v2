// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolRewards {
    function claimable(address) external view returns (uint256);
    function claimReward(address) external;
 }
