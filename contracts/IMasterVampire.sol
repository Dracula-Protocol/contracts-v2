// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./VampireAdapter.sol";
import "./ChiGasSaver.sol";

/**
* @title Interface for MV and adapters that follows the `Inherited Storage` pattern
* This allows adapters to add storage variables locally without causing collisions.
* Adapters simply need to inherit this interface so that new variables are appended.
*/
abstract contract IMasterVampire is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VampireAdapter for Victim;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 coolOffTime;
        uint256 poolShares;
    }

    struct PoolInfo {
        Victim victim;
        uint256 victimPoolId;
        uint256 lastRewardBlock;
        uint256 accWethPerShare;
        uint256 wethAccumulator;
        // Base amount of shares from user deposits for victims that return shares for the pool.
        uint256 basePoolShares;
        uint256 baseDeposits;
    }

    address public IBVETH;

    address public drainController;
    address public drainAddress;
    address public poolRewardUpdater;
    address public devAddress;
    uint256 public distributionPeriod = 6519; // Blocks in 24 hour period
    uint256 public withdrawalPenalty = 10;
    uint256 public wethDrainModifier = 150;

    // Info of each pool
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
}
