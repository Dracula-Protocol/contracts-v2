// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYearnV2Vault is IERC20 {
    function deposit(uint256 amount) external returns (uint256);
    function deposit() external returns (uint256);
    function withdraw(uint256 shares) external;
    function withdraw() external;
    function pricePerShare() external view returns (uint256);
}
