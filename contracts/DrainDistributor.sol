// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IWETH.sol";

interface ILpController {
    function addLiquidity(uint256 amount) external;
}

interface IRewardPool {
    function fundPool(uint256 reward) external;
}

interface IDrainController {
    function distribute() external;
}

/**
* @title Receives rewards from MasterVampire via drain and redistributes
*/
contract DrainDistributor is Ownable {
    using SafeMath for uint256;
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Distribution
    // Percentages are using decimal base of 1000 ie: 10% = 100
    uint256 public gasShare = 50;
    uint256 public devShare = 150;
    uint256 public uniRewardPoolShare = 200;
    uint256 public yflRewardPoolShare = 200;
    uint256 public lpShare = 400;

    address public devFund = 0xa896e4bd97a733F049b23d2AcEB091BcE01f298d;
    address public uniRewardPool;
    address public yflRewardPool;
    address public lpController;
    address payable public drainController;

    /**
     * @notice Construct the contract
     * @param uniRewardPool_ address of the uniswap LP reward pool
     * @param yflRewardPool_ address of the linkswap LP reward pool
     * @param lpController_ address of the LP controller
     */
    constructor(address uniRewardPool_, address yflRewardPool_, address lpController_) public {
        require((gasShare + devShare + uniRewardPoolShare + yflRewardPoolShare + lpShare) == 1000, "invalid distribution");
        uniRewardPool = uniRewardPool_;
        yflRewardPool = yflRewardPool_;
        lpController = lpController_;
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    /**
     * @notice Distributes drained rewards
     */
    function distribute() external {
        require((gasShare + devShare + uniRewardPoolShare + yflRewardPoolShare + lpShare) == 1000, "invalid distribution");
        uint256 drainWethBalance = WETH.balanceOf(address(this));
        uint256 gasAmt = drainWethBalance.mul(gasShare).div(1000);
        uint256 devAmt = drainWethBalance.mul(devShare).div(1000);
        uint256 uniRewardPoolAmt = drainWethBalance.mul(uniRewardPoolShare).div(1000);
        uint256 yflRewardPoolAmt = drainWethBalance.mul(yflRewardPoolShare).div(1000);
        uint256 lpAmt = drainWethBalance.mul(lpShare).div(1000);

        // Unwrap WETH and transfer ETH to DrainController to cover drain gas fees
        WETH.withdraw(gasAmt);
        drainController.transfer(gasAmt);
        // Treasury
        WETH.transfer(devFund, devAmt);
        // Reward pools
        WETH.approve(uniRewardPool, uniRewardPoolAmt);
        IRewardPool(uniRewardPool).fundPool(uniRewardPoolAmt);
        WETH.approve(yflRewardPool, yflRewardPoolAmt);
        IRewardPool(yflRewardPool).fundPool(yflRewardPoolAmt);
        // Buy-back liquidity addition
        WETH.approve(lpController, lpAmt);
        ILpController(lpController).addLiquidity(lpAmt);
    }

    /**
     * @notice Changes the distribution percentage
     *         Percentages are using decimal base of 1000 ie: 10% = 100
     */
    function changeDistribution(
        uint256 gasShare_,
        uint256 devShare_,
        uint256 uniRewardPoolShare_,
        uint256 yflRewardPoolShare_,
        uint256 lpShare_)
        external
        onlyOwner
    {
        require((gasShare_ + devShare_ + uniRewardPoolShare_ + yflRewardPoolShare_ + lpShare_) == 1000, "invalid distribution");
        gasShare = gasShare_;
        devShare = devShare_;
        uniRewardPoolShare = uniRewardPoolShare_;
        yflRewardPoolShare = uniRewardPoolShare_;
        lpShare = lpShare_;
    }

    /**
     * @notice Changes the address of the dev treasury
     * @param devFund_ the new address
     */
    function changeDev(address devFund_) external onlyOwner {
        require(devFund_ != address(0));
        devFund = devFund_;
    }

    /**
     * @notice Changes the address of the LP controller
     * @param lpController_ the new address
     */
    function changeLp(address lpController_) external onlyOwner {
        require(lpController_ != address(0));
        lpController = lpController_;
    }

    /**
     * @notice Changes the address of the Drain controller
     * @param drainController_ the new address
     */
    function changeDrainController(address payable drainController_) external onlyOwner {
        require(drainController_ != address(0));
        drainController = drainController_;
    }

    /**
     * @notice Changes the address of the uniswap LP reward pool
     * @param rewardPool_ the new address
     */
    function changeUniRewardPool(address rewardPool_) external onlyOwner {
        require(rewardPool_ != address(0));
        uniRewardPool = rewardPool_;
    }

     /**
     * @notice Changes the address of the linkswap LP reward pool
     * @param rewardPool_ the new address
     */
    function changeYFLRewardPool(address rewardPool_) external onlyOwner {
        require(rewardPool_ != address(0));
        yflRewardPool = rewardPool_;
    }
}
