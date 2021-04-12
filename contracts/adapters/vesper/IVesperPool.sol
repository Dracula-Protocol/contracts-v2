// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVesperPool {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function withdrawFee() external view returns (uint256); //TODO: KIV - currently it's 0
    function tokenLocked() external view returns (uint256);
    function token() external view returns (address);
    function balanceOf(address) external view returns (uint256); //TODO: can I use that for lockedValue?
    function controller(address) external view returns (address);
}
