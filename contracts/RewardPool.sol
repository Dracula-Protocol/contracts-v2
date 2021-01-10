// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IRewardSupplier.sol";

/// @title A reward pool that does not mint
/// @dev The rewards are transferred to the pool by calling `fundPool`.
///      Only the reward supplier can notify.
contract RewardPool is IRewardSupplier, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public stakingToken;
    IERC20 public rewardToken;
    uint256 public rewardsDuration;

    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address rewardToken_,
        address stakingToken_,
        uint256 rewardsDuration_,
        address rewardSupplier_) public
        IRewardSupplier(rewardSupplier_)
    {
        rewardToken = IERC20(rewardToken_);
        stakingToken = IERC20(stakingToken_);
        rewardsDuration = rewardsDuration_;
    }

    /// @notice Staked balance for account
    function balanceOf(address account) external view returns (uint256) {
        return stakedBalances[account];
    }

    /// @notice Last time rewards were applicable
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @notice Reward per token staked
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalStaked)
            );
    }

    /// @notice Total rewards to distribute for the duration
    function rewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /// @notice Calculate the earned rewards for an account
    /// @return amount earned by specified account
    function earned(address account) public view returns (uint256) {
        return
            stakedBalances[account]
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    /// @notice Stake specified amount
    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalStaked = totalStaked.add(amount);
        stakedBalances[msg.sender] = stakedBalances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw specified amount and collect rewards
    function unstake(uint256 amount) external {
        withdraw(amount);
        getReward();
    }

    /// @notice Claims reward for the sender account
    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            uint256 contractBalance = rewardToken.balanceOf(address(this));
            if (contractBalance < reward) {
                reward = contractBalance; // Prevents contract from locking up
            }
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @notice Withdraw specified amount
    function withdraw(uint256 amount) internal virtual nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        uint256 amount_send = amount;
        totalStaked = totalStaked.sub(amount);
        stakedBalances[msg.sender] = stakedBalances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount_send);
        emit Withdrawn(msg.sender, amount_send);
    }

    /// @notice Transfers reward amount to pool and updates reward rate
    /// @dev Should be called by external mechanism
    function fundPool(uint256 reward)
        external
        override
        onlyRewardSupplier
        updateReward(address(0))
    {
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        require(reward < uint(-1) / 1e18, "the notified reward cannot invoke multiplication overflow");

        rewardToken.safeTransferFrom(msg.sender, address(this), reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }
}
