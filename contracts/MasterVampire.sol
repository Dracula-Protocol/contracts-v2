// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/Math.sol";
import "./IMasterVampire.sol";
import "./IIBVEth.sol";

contract MasterVampire is IMasterVampire, ChiGasSaver {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using VampireAdapter for Victim;
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
    event RewardClaimed(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ETHValue(uint256 amount);
    event DrainedReward(uint256 indexed pid, uint256 amount);

    IWETH immutable weth;

    modifier onlyDev() {
        require(devAddress == msg.sender, "not dev");
        _;
    }

    modifier onlyRewardUpdater() {
        require(poolRewardUpdater == msg.sender, "not reward updater");
        _;
    }

    modifier updateReward(uint256 _pid, address _user) {
        PoolInfo storage pool = poolInfo[_pid];
        pool.accWethPerShare = wethPerShare(_pid);
        pool.lastUpdateBlock = lastTimeRewardApplicable(_pid);
        if (_user != address(0)) {
            UserInfo storage user = userInfo[_pid][_user];
            user.rewards = pendingWeth(_pid, _user);
            user.rewardDebt = pool.accWethPerShare;
        }
        _;
    }

    constructor(
        address _drainAddress,
        address _drainController,
        address _IBVETH,
        address _weth
    ) {
        drainAddress = _drainAddress;
        drainController = _drainController;
        devAddress = msg.sender;
        poolRewardUpdater = msg.sender;
        IBVETH = _IBVETH;
        weth = IWETH(_weth);
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(Victim _victim, uint256 _victimPoolId) external onlyOwner {
        poolInfo.push(PoolInfo({
            victim: _victim,
            victimPoolId: _victimPoolId,
            lastUpdateBlock: 0,
            accWethPerShare: 0,
            wethAccumulator: 0,
            rewardRate: 0,
            periodFinish: 0,
            basePoolShares: 0,
            baseDeposits: 0
        }));
    }

    // Add multiple pools for one victim
    function addBulk(Victim _victim, uint256[] memory victimPids) external onlyOwner {
        for (uint i = 0; i < victimPids.length; i++) {
            poolInfo.push(PoolInfo({
                victim: _victim,
                victimPoolId: victimPids[i],
                lastUpdateBlock: 0,
                accWethPerShare: 0,
                wethAccumulator: 0,
                rewardRate: 0,
                periodFinish: 0,
                basePoolShares: 0,
                baseDeposits: 0
            }));
        }
    }

    function updateDistributionPeriod(uint256 _distributionPeriod) external onlyRewardUpdater {
        distributionPeriod = _distributionPeriod;
    }

    function updateVictimAddress(uint256 _pid, address _victim) external onlyOwner {
        poolInfo[_pid].victim = Victim(_victim);
    }

    function updateVictimAddressBulk(uint256[] memory pids, address _victim) public onlyRewardUpdater {
        for (uint i = 0; i < pids.length; i++) {
            uint256 pid = pids[i];
            poolInfo[pid].victim = Victim(_victim);
        }
    }

    function updateVictimInfo(uint256 _pid, address _victim, uint256 _victimPoolId) external onlyOwner {
        poolInfo[_pid].victim = Victim(_victim);
        poolInfo[_pid].victimPoolId = _victimPoolId;
    }

    function updatePoolDrain(uint256 _wethDrainModifier) external onlyOwner {
        wethDrainModifier = _wethDrainModifier;
    }

    function updateDevAddress(address _devAddress) external onlyDev {
        devAddress = _devAddress;
    }

    function updateDrainAddress(address _drainAddress) external onlyOwner {
        drainAddress = _drainAddress;
    }

    function updateIBEthStrategy(address _ibveth) external onlyOwner {
        IBVETH = _ibveth;
        (bool success,) = address(IBVETH).delegatecall(abi.encodeWithSignature("migrate()"));
        require(success, "migrate() delegatecall failed.");
    }

    function updateDrainController(address _drainController) external onlyOwner {
        drainController = _drainController;
    }

    function updateRewardUpdaterAddress(address _poolRewardUpdater) external onlyOwner {
        poolRewardUpdater = _poolRewardUpdater;
    }

    function lastTimeRewardApplicable(uint256 _pid) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return Math.min(block.number, pool.periodFinish);
    }

    // WETH reward per staked share
    function wethPerShare(uint256 _pid) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 totalStaked = pool.victim.lockedAmount(pool.victimPoolId);
        if (totalStaked == 0) {
            return pool.accWethPerShare;
        }
        return
            pool.accWethPerShare.add(
                lastTimeRewardApplicable(_pid)
                    .sub(pool.lastUpdateBlock)
                    .mul(pool.rewardRate)
                    .mul(1e18)
                    .div(totalStaked)
            );
    }

    // Total rewards to distribute for the duration
    function rewardForDuration(uint256 _pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return pool.rewardRate.mul(distributionPeriod);
    }

    // Returns the interest-bearing ETH value
    function pendingWeth(uint256 _pid, address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return
            user.amount
                .mul(wethPerShare(_pid).sub(user.rewardDebt))
                .div(1e18)
                .add(user.rewards);
    }

    // Returns the actual WETH value (interest-bearing ETH converted)
    function pendingWethReal(uint256 _pid, address _user) external returns (uint256) {
        uint256 ibETH = pendingWeth(_pid, _user);
        uint256 ethVal = IIBVEth(IBVETH).ibETHValue(ibETH);
        emit ETHValue(ethVal);
        return ethVal;
    }

    // Returns the underlying pending rewards for a victim
    function pendingVictimReward(uint256 pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        return pool.victim.pendingReward(pid, pool.victimPoolId);
    }

    // Returns the current drained/accumulated rewards for a pool
    function poolAccWeth(uint256 pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        return pool.wethAccumulator;
    }

    function deposit(uint256 pid, uint256 amount) external nonReentrant updateReward(pid, msg.sender) {
        require(amount > 0, "Cannot deposit 0");
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        pool.victim.lockableToken(pool.victimPoolId).safeTransferFrom(address(msg.sender), address(this), amount);
        uint256 shares = pool.victim.deposit(pool.victimPoolId, amount);
        if (shares > 0) {
            pool.basePoolShares = pool.basePoolShares.add(shares);
            pool.baseDeposits = pool.baseDeposits.add(amount);
            user.poolShares = user.poolShares.add(shares);
        }
        user.amount = user.amount.add(amount);
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount, uint256 tipAmount, uint8 flag) external payable nonReentrant updateReward(pid, msg.sender) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(amount > 0 && user.amount >= amount, "withdraw: not good");

        user.amount = user.amount.sub(amount);
        uint256 shares = pool.victim.withdraw(pool.victimPoolId, amount);
        if (shares > 0) {
            pool.basePoolShares = pool.basePoolShares.sub(shares);
            pool.baseDeposits = pool.baseDeposits.sub(amount);
            user.poolShares = user.poolShares.sub(shares);
        }
        pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), amount);
        _claim(pid, tipAmount, flag);
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid, uint256 tipAmount, uint8 flag) external payable nonReentrant updateReward(pid, msg.sender) {
        _claim(pid, tipAmount, flag);
    }

    // Withdraw in case of emergency. No rewards will be claimed.
    function emergencyWithdraw(uint256 pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        pool.victim.withdraw(pool.victimPoolId, user.amount);
        pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, pid, user.amount);
        user.amount = 0;
        user.rewards = 0;
        user.rewardDebt = 0;
        user.poolShares = 0;
    }

    /// Can only be called by DrainController
    function drain(uint256 pid) external updateReward(pid, address(0)) {
        require(drainController == msg.sender, "not drainctrl");
        PoolInfo storage pool = poolInfo[pid];
        Victim victim = pool.victim;
        uint256 victimPoolId = pool.victimPoolId;
        victim.claimReward(pid, victimPoolId);
        IERC20 rewardToken = victim.rewardToken(pid);
        uint256 claimedReward = rewardToken.balanceOf(address(this));

        if (claimedReward == 0) {
            return;
        }

        uint256 wethReward = victim.sellRewardForWeth(pid, claimedReward, address(this));

        // Take a % of the drained reward to be redistributed to other contracts
        uint256 wethDrainAmount = wethReward.mul(wethDrainModifier).div(1000);
        if (wethDrainAmount > 0) {
            weth.transfer(drainAddress, wethDrainAmount);
            wethReward = wethReward.sub(wethDrainAmount);
        }

        // Remainder of rewards go to users of the drained pool as interest-bearing ETH
        uint256 ibethBefore = IIBVEth(IBVETH).balance(address(this));
        (bool success,) = IBVETH.delegatecall(abi.encodeWithSignature("handleDrainedWETH(uint256)", wethReward));
        require(success, "handleDrainedWETH(uint256 amount) delegatecall failed.");
        uint256 ibethAfter = IIBVEth(IBVETH).balance(address(this));
        uint256 newRewards = ibethAfter.sub(ibethBefore);
        pool.wethAccumulator = pool.wethAccumulator.add(newRewards);

        if (block.number >= pool.periodFinish) {
            pool.rewardRate = newRewards.div(distributionPeriod);
        } else {
            uint256 remaining = pool.periodFinish.sub(block.number);
            uint256 leftover = remaining.mul(pool.rewardRate);
            pool.rewardRate = newRewards.add(leftover).div(distributionPeriod);
        }

        pool.lastUpdateBlock = block.number;
        pool.periodFinish = block.number.add(distributionPeriod);
        emit DrainedReward(pid, newRewards);
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
    function _claim(uint256 pid, uint256 tipAmount, uint8 flag) internal {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 pending = user.rewards;
        if (pending > 0) {
            user.rewards = 0;
            uint256 poolBalance = pool.wethAccumulator;
            if (poolBalance < pending) {
                pending = poolBalance; // Prevents contract from locking up
            }
            (bool success,) = address(IBVETH).delegatecall(abi.encodeWithSignature("handleClaim(uint256,uint256,uint8)", pending, tipAmount, flag));
            require(success, "handleClaim(uint256 pending, uint256 tipAmount, uint8 flag) delegatecall failed.");
            emit RewardClaimed(msg.sender, pid, pending);
        }
    }
}
