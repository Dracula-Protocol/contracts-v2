// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./IMasterVampire.sol";

import "hardhat/console.sol";

contract MasterVampire is IMasterVampire {
    //     (_                   _)
    //      /\                 /\
    //     / \'._   (\_/)   _.'/ \
    //    /_.''._'--('.')--'_.''._\
    //    | \_ / `;=/ " \=;` \ _/ |
    //     \/ `\__|`\___/`|__/`  \/
    //   jgs`      \(/|\)/       `
    //              " ` "
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier onlyDev() {
        require(devAddress == _msgSender(), "not dev");
        _;
    }

    modifier onlyRewardUpdater() {
        require(poolRewardUpdater == _msgSender(), "not reward updater");
        _;
    }

    constructor(
        address _drainAddress,
        address _drainController,
        address _IBVETH
    ) public {
        drainAddress = _drainAddress;
        drainController = _drainController;
        devAddress = msg.sender;
        poolRewardUpdater = msg.sender;
        IBVETH = _IBVETH;
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(Victim _victim, uint256 _victimPoolId, uint256 _wethDrainModifier, uint8 flag) external onlyOwner saveGas(flag) {
        poolInfo.push(PoolInfo({
            victim: _victim,
            victimPoolId: _victimPoolId,
            wethDrainModifier: _wethDrainModifier,
            lastRewardBlock: block.number,
            accWethPerShare: 0,
            wethAccumulator: 0
        }));
    }

    function updateDistributionPeriod(uint256 _distributionPeriod) external onlyRewardUpdater {
        distributionPeriod = _distributionPeriod;
    }

    function updateWithdrawPenalty(uint256 _withdrawalPenalty) external onlyRewardUpdater {
        withdrawalPenalty = _withdrawalPenalty;
    }

    function updateVictimInfo(uint256 _pid, address _victim, uint256 _victimPoolId) external onlyOwner {
        poolInfo[_pid].victim = Victim(_victim);
        poolInfo[_pid].victimPoolId = _victimPoolId;
    }

    function updatePoolDrain(uint256 _pid, uint256 _wethDrainModifier) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.wethDrainModifier = _wethDrainModifier;
    }

    function updateDevAddress(address _devAddress) external onlyDev {
        devAddress = _devAddress;
    }

    function updateDrainAddress(address _drainAddress) external onlyOwner {
        drainAddress = _drainAddress;
    }

    function updateIBVEthAddress(address _ibveth) external onlyOwner {
        IBVETH = _ibveth;
    }

    function updateDrainController(address _drainController) external onlyOwner {
        drainController = _drainController;
    }

    function updateRewardUpdaterAddress(address _poolRewardUpdater) external onlyOwner {
        poolRewardUpdater = _poolRewardUpdater;
    }

    function pendingWeth(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accWethPerShare = pool.accWethPerShare;
        uint256 lpSupply = pool.victim.lockedAmount(pool.victimPoolId);
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocksToReward = block.number.sub(pool.lastRewardBlock);
            uint256 wethReward = blocksToReward.mul(pool.wethAccumulator).div(distributionPeriod);
            accWethPerShare = accWethPerShare.add(wethReward.mul(1e12).div(lpSupply));
        }

        return user.amount.mul(accWethPerShare).div(1e12).sub(user.rewardDebt);
    }

    function poolAccWeth(uint256 pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        return pool.wethAccumulator;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 pid) public {
        PoolInfo storage pool = poolInfo[pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = pool.victim.lockedAmount(pool.victimPoolId);
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 blocksToReward = block.number.sub(pool.lastRewardBlock);
        uint256 wethReward = blocksToReward.mul(pool.wethAccumulator).div(distributionPeriod);
        pool.accWethPerShare = pool.accWethPerShare.add(wethReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
        pool.wethAccumulator = pool.wethAccumulator.sub(wethReward);
    }

    function deposit(uint256 pid, uint256 amount, uint8 flag) external nonReentrant saveGas(flag) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        user.coolOffTime = block.timestamp + 24 hours;

        updatePool(pid);
        if (user.amount > 0) {
            _claim(pid, false);
        }

        if (amount > 0) {
            pool.victim.lockableToken(pool.victimPoolId).safeTransferFrom(address(msg.sender), address(this), amount);
            pool.victim.deposit(pool.victimPoolId, amount);
            user.amount = user.amount.add(amount);
        }

        user.rewardDebt = user.amount.mul(pool.accWethPerShare).div(1e12);
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount, uint8 flag) external nonReentrant saveGas(flag) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(user.amount >= amount, "withdraw: not good");
        updatePool(pid);
        _claim(pid, true);

        if (amount > 0) {
            user.amount = user.amount.sub(amount);
            pool.victim.withdraw(pool.victimPoolId, amount);
            pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), amount);
        }

        user.rewardDebt = user.amount.mul(pool.accWethPerShare).div(1e12);
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid, uint8 flag) external nonReentrant saveGas(flag) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        _claim(pid, false);
        user.rewardDebt = user.amount.mul(pool.accWethPerShare).div(1e12);
    }

    function emergencyWithdraw(uint256 pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        pool.victim.withdraw(pool.victimPoolId, user.amount);
        pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    /// Can only be called by DrainController
    function drain(uint256 pid) external {
        require(drainController == _msgSender(), "not drainctrl");
        PoolInfo storage pool = poolInfo[pid];
        Victim victim = pool.victim;
        uint256 victimPoolId = pool.victimPoolId;
        victim.claimReward(victimPoolId);
        IERC20 rewardToken = victim.rewardToken(pid);
        uint256 claimedReward = rewardToken.balanceOf(address(this));

        if (claimedReward == 0) {
            return;
        }

        uint256 wethReward = victim.sellRewardForWeth(pid, claimedReward, address(this));
        // Take a % of the drained reward to be redistributed to other contracts
        uint256 wethDrainAmount = wethReward.mul(pool.wethDrainModifier).div(1000);
        if (wethDrainAmount > 0) {
            WETH.transfer(drainAddress, wethDrainAmount);
            wethReward = wethReward.sub(wethDrainAmount);
        }

        // Remainder of rewards go to users of the drained pool
        (bool success,) = address(IBVETH).delegatecall(abi.encodeWithSignature("handleDrainedWETH(uint256)", wethReward));
        require(success, "handleDrainedWETH(uint256 amount) delegatecall failed.");

        pool.wethAccumulator = pool.wethAccumulator.add(wethReward);
    }

    /// This function allows owner to take unsupported tokens out of the contract.
    /// It also allows for removal of airdropped tokens.
    function recoverUnsupported(IERC20 token, uint256 amount, address to) external onlyOwner {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            IERC20 lpToken = pool.victim.lockableToken(pool.victimPoolId);
            // cant take staked asset
            require(token != lpToken, "!pool.lpToken");
        }
        // transfer to
        token.safeTransfer(to, amount);
    }

    /// Claim rewards from pool
    function _claim(uint256 pid, bool withdrawing) internal {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 pending = user.amount.mul(pool.accWethPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            if (withdrawing && withdrawalPenalty > 0 && block.timestamp < user.coolOffTime) {
                uint256 fee = pending.mul(withdrawalPenalty).div(1000);
                pending = pending.sub(fee);
                pool.wethAccumulator = pool.wethAccumulator.add(fee);
            }

            (bool success,) = address(IBVETH).delegatecall(abi.encodeWithSignature("handleClaim(uint256)", pending));
            require(success, "handleClaim(uint256 pending) delegatecall failed.");
        }
    }

    function _safeWethTransfer(address to, uint256 amount) internal {
        uint256 balance = WETH.balanceOf(address(this));
        if (amount > balance) {
            WETH.transfer(to, balance);
        } else {
            WETH.transfer(to, amount);
        }
    }
}
