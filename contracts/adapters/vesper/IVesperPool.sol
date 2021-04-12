// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVesperPool {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
    function withdrawFee() external view returns (uint256); //TODO: KIV - currently it's 0
    function tokenLocked() external view returns (uint256);
    function controller() external view returns (address);
    function token() external view returns (IERC20);
}
