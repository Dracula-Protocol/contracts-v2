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
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event ETHValue(uint256 amount);

    IWETH immutable weth;

    modifier onlyDev() {
        require(devAddress == msg.sender, "not dev");
        _;
    }

    modifier onlyRewardUpdater() {
        require(poolRewardUpdater == msg.sender, "not reward updater");
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
            lastRewardBlock: block.number,
            accWethPerShare: 0,
            wethAccumulator: 0,
            basePoolShares: 0,
            baseDeposits: 0
        }));
    }

    function updateDistributionPeriod(uint256 _distributionPeriod) external onlyRewardUpdater {
        distributionPeriod = _distributionPeriod;
    }

    function updateWithdrawPenalty(uint256 _withdrawalPenalty) external onlyRewardUpdater {
        withdrawalPenalty = _withdrawalPenalty;
    }

    function updateVictimAddress(uint256 _pid, address _victim) external onlyOwner {
        poolInfo[_pid].victim = Victim(_victim);
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

    function pendingWeth(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accWethPerShare = pool.accWethPerShare;
        uint256 lpSupply = pool.victim.lockedAmount(pool.victimPoolId);
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocksToReward = Math.min(block.number.sub(pool.lastRewardBlock), distributionPeriod);
            uint256 wethReward = Math.min(blocksToReward.mul(pool.wethAccumulator).div(distributionPeriod), pool.wethAccumulator);
            accWethPerShare = accWethPerShare.add(wethReward.mul(1e12).div(lpSupply));
        }

        return user.amount.mul(accWethPerShare).div(1e12).sub(user.rewardDebt);
    }

    function pendingWethReal(uint256 _pid, address _user) external returns (uint256) {
        uint256 ibETH = pendingWeth(_pid, _user);
        uint256 ethVal = IIBVEth(IBVETH).ibETHValue(ibETH);
        emit ETHValue(ethVal);
        return ethVal;
    }

    function pendingVictimReward(uint256 pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        return pool.victim.pendingReward(pid, pool.victimPoolId);
    }

    function poolAccWeth(uint256 pid) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        return pool.wethAccumulator;
    }

    function massUpdatePools() external {
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

        uint256 blocksToReward = Math.min(block.number.sub(pool.lastRewardBlock), distributionPeriod);
        uint256 wethReward = Math.min(blocksToReward.mul(pool.wethAccumulator).div(distributionPeriod), pool.wethAccumulator);
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
            _claim(pid, false, flag);
        }

        if (amount > 0) {
            pool.victim.lockableToken(pool.victimPoolId).safeTransferFrom(address(msg.sender), address(this), amount);
            uint256 shares = pool.victim.deposit(pool.victimPoolId, amount);
            if (shares > 0) {
                pool.basePoolShares = pool.basePoolShares.add(shares);
                pool.baseDeposits = pool.baseDeposits.add(amount);
                user.poolShares = user.poolShares.add(shares);
            }
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
        _claim(pid, true, flag);

        if (amount > 0) {
            user.amount = user.amount.sub(amount);
            uint256 shares = pool.victim.withdraw(pool.victimPoolId, amount);
            if (shares > 0) {
                pool.basePoolShares = pool.basePoolShares.sub(shares);
                pool.baseDeposits = pool.baseDeposits.sub(amount);
                user.poolShares = user.poolShares.sub(shares);
            }
            pool.victim.lockableToken(pool.victimPoolId).safeTransfer(address(msg.sender), amount);
        }

        user.rewardDebt = user.amount.mul(pool.accWethPerShare).div(1e12);
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid, uint8 flag) external nonReentrant saveGas(flag) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        _claim(pid, false, flag);
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
        user.poolShares = 0;
    }

    /// Can only be called by DrainController
    function drain(uint256 pid) external {
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

        if (pool.wethAccumulator == 0) {
            pool.wethAccumulator = ibethAfter;
        } else {
            pool.wethAccumulator = pool.wethAccumulator.add(ibethAfter.sub(ibethBefore));
        }
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
    function _claim(uint256 pid, bool withdrawing, uint8 flag) internal {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        uint256 pending = user.amount.mul(pool.accWethPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            if (withdrawing && withdrawalPenalty > 0 && block.timestamp < user.coolOffTime) {
                uint256 fee = pending.mul(withdrawalPenalty).div(1000);
                pending = pending.sub(fee);
                pool.wethAccumulator = pool.wethAccumulator.add(fee);
            }

            (bool success,) = address(IBVETH).delegatecall(abi.encodeWithSignature("handleClaim(uint256,uint8)", pending, flag));
            require(success, "handleClaim(uint256 pending, uint8 flag) delegatecall failed.");
        }
    }

    function _safeWethTransfer(address to, uint256 amount) internal {
        uint256 balance = weth.balanceOf(address(this));
        if (amount > balance) {
            weth.transfer(to, balance);
        } else {
            weth.transfer(to, amount);
        }
    }
}
