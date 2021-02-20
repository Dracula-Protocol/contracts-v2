// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;

interface IRariFundManager {
    function deposit() external payable;
    function withdraw(uint256 amount) external returns (bool);
}