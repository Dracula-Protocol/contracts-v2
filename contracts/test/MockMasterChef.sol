// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Mock.sol";

// MockMasterChef is the master of mocks.
contract MockMasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Mock to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Mock distribution occurs.
        uint256 accMockPerShare; // Accumulated Mock per share, times 1e12. See below.
    }

    // The TOKEN
    ERC20Mock public token;
    // Reward updater
    address public rewardUpdater;
    // Block number when bonus Mock period ends.
    uint256 public bonusEndBlock;
    // Mock tokens created per block.
    uint256 public tokenPerBlock;
    // Bonus muliplier for early token makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when Mock mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claimed(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier onlyRewardUpdater() {
        require(rewardUpdater == _msgSender(), "not reward updater");
        _;
    }

    constructor(
        ERC20Mock token_,
        uint256 tokenPerBlock_,
        uint256 startBlock_,
        uint256 bonusEndBlock_
    ) public {
        token = token_;
        rewardUpdater = _msgSender();
        tokenPerBlock = tokenPerBlock_;
        bonusEndBlock = bonusEndBlock_;
        startBlock = startBlock_;
    }

    /// Return the number of pools
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @notice Sets the reward updater address
     * @param rewardUpdaterAddress_ address where rewards are sent
     */
    function setRewardUpdater(address rewardUpdaterAddress_) external onlyRewardUpdater {
        rewardUpdater = rewardUpdaterAddress_;
    }

    /**
     * @notice Sets the rewards per block
     * @param rewardPerBlock amount of rewards minted per block
     */
    function setRewardPerBlock(uint256 rewardPerBlock) external onlyRewardUpdater {
        massUpdatePools();
        tokenPerBlock = rewardPerBlock;
    }

    function add(uint256 allocPoint, IERC20 lpToken) external onlyOwner {
        massUpdatePools();
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: lpToken,
            allocPoint: allocPoint,
            lastRewardBlock: lastRewardBlock,
            accMockPerShare: 0
        }));
    }

    function set(uint256 pid, uint256 allocPoint) external onlyOwner {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[pid].allocPoint).add(allocPoint);
        poolInfo[pid].allocPoint = allocPoint;
    }

    function getMultiplier(uint256 from, uint256 to) public view returns (uint256) {
        if (to <= bonusEndBlock) {
            return to.sub(from).mul(BONUS_MULTIPLIER);
        } else if (from >= bonusEndBlock) {
            return to.sub(from);
        } else {
            return bonusEndBlock.sub(from).mul(BONUS_MULTIPLIER).add(
                to.sub(bonusEndBlock)
            );
        }
    }

    function pendingMock(uint256 pid, address user_) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][user_];
        uint256 accMockPerShare = pool.accMockPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accMockPerShare = accMockPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accMockPerShare).div(1e12).sub(user.rewardDebt);
    }

    /// Update reward variables for all pools. Be careful of gas spending!
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
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        // Since we cannot mint existing tokens on forked mainnet, this contract gets funded by the reward token first
        //token.mint(address(this), tokenReward);
        pool.accMockPerShare = pool.accMockPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 pid, uint256 amount) external {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        if (user.amount > 0) {
            _claim(pid);
        }
        if (amount > 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), amount);
            user.amount = user.amount.add(amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMockPerShare).div(1e12);
        emit Deposit(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        require(user.amount >= amount, "withdraw: not good");
        updatePool(pid);
        _claim(pid);

        if (amount > 0) {
            user.amount = user.amount.sub(amount);
            pool.lpToken.safeTransfer(msg.sender, amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMockPerShare).div(1e12);
        emit Withdraw(msg.sender, pid, amount);
    }

    function claim(uint256 pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        updatePool(pid);
        _claim(pid);
        user.rewardDebt = user.amount.mul(pool.accMockPerShare).div(1e12);
    }

    function emergencyWithdraw(uint256 pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount);
    }

    /// Claim rewards from pool
    function _claim(uint256 pid) internal {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 pending = user.amount.mul(pool.accMockPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            _safeTokenTransfer(msg.sender, pending);
            emit Claimed(msg.sender, pid, pending);
        }
    }

    function _safeTokenTransfer(address to, uint256 amount) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        if (amount > tokenBal) {
            token.transfer(to, tokenBal);
        } else {
            token.transfer(to, amount);
        }
    }
}