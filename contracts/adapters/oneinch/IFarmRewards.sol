// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFarmRewards {
	function getBalanceForAddition(IERC20 token) external view returns(uint256);
	function balanceOf(address account) external view returns (uint256);
	function earned(uint i, address account) external view returns (uint256);
	function stake(uint256 amount) external;
	function withdraw(uint256 amount) external;
	function getReward(uint i) external;
}
