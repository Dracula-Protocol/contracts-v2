// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapPool {
    // Views
    function stakingToken() external view returns (IERC20);

    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    // Mutative

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;
}
