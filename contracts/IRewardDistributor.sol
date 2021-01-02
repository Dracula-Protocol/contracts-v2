// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract IRewardDistributor is Ownable {
    address rewardDistributor;

    constructor(address _rewardDistributor) public {
        rewardDistributor = _rewardDistributor;
    }

    function fundPool(uint256 reward) external virtual;

    modifier onlyRewardDistributor() {
        require(_msgSender() == rewardDistributor, "Caller is not reward distributor");
        _;
    }

    function setRewardDistributor(address _rewardDistributor)
        external
        onlyOwner
    {
        rewardDistributor = _rewardDistributor;
    }
}