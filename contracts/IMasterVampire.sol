// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Timelock.sol";
import "./VampireAdapter.sol";
import "./ChiGasSaver.sol";

abstract contract IMasterVampire is Ownable, Timelock, ReentrancyGuard, ChiGasSaver {
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
        uint256 wethDrainModifier;
    }

    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address public drainController;
    address public drainAddress;
    address public poolRewardUpdater;
    address public devAddress;
    uint256 public distributionPeriod = 6519; // Block in 24 hour period
    uint256 public withdrawalPenalty = 10;
    uint256 public constant REWARD_START_BLOCK = 11008888; // Wed Oct 07 2020 13:28:00 UTC

    PoolInfo[] public poolInfo;

    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
}