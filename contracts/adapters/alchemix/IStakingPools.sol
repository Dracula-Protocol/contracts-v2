// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakingPools {
    function poolCount() external view returns (uint256);

    function getPoolToken(uint256 _poolId) external view returns (IERC20);

    function getStakeTotalDeposited(address _account, uint256 _poolId)
        external
        view
        returns (uint256);

    function getStakeTotalUnclaimed(address _account, uint256 _poolId)
        external
        view
        returns (uint256);

    function deposit(uint256 _poolId, uint256 _depositAmount) external;

    function withdraw(uint256 _poolId, uint256 _withdrawAmount) external;

    function claim(uint256 _poolId) external;
}
