// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "./DraculaToken.sol";
import "./RewardPool.sol";

/// @title Stake DRC and earn WETH for rewards
contract DRCRewardPool is RewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public burnRate = 10; // default 1%

    constructor(
        address rewardToken_,
        address stakingToken_,
        uint256 rewardsDuration_,
        address rewardSupplier_)
        RewardPool(rewardToken_, stakingToken_, rewardsDuration_, rewardSupplier_)
    {
    }

    function setBurnRate(uint256 _burnRate) external onlyOwner {
        require(_burnRate <= 100, "Invalid burn rate value");
        burnRate = _burnRate;
    }

    /// @notice Withdraw specified amount
    /// @dev A configurable percentage of DRC is burnt on withdrawal
    function _withdraw(uint256 amount) internal override nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        uint256 amount_send = amount;

        if (burnRate > 0) {
            uint256 amount_burn = amount.mul(burnRate).div(1000);
            amount_send = amount.sub(amount_burn);
            require(amount == amount_send.add(amount_burn), "Burn value invalid");
            DraculaToken(address(stakingToken)).burn(amount_burn);
        }

        totalStaked = totalStaked.sub(amount);
        stakedBalances[msg.sender] = stakedBalances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount_send);
        emit Withdrawn(msg.sender, amount_send);
    }
}
