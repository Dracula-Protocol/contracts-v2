// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRariFundManager {
    function deposit() external payable;
    function withdraw(uint256 amount) external returns (bool);
    function rariFundToken() external view returns (IERC20);
    function balanceOf(address account) external returns (uint256);
    function getFundBalance() external returns (uint256);
}