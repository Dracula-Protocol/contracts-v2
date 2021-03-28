// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IWETH.sol";

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
    IWETH immutable WETH;

    // Distribution
    // Percentages are using decimal base of 1000 ie: 10% = 100
    uint256 public gasShare = 100;
    uint256 public devShare = 250;
    uint256 public uniRewardPoolShare = 200;
    uint256 public yflRewardPoolShare = 200;
    uint256 public drcRewardPoolShare = 250;
    uint256 public wethThreshold = 200000000000000000 wei;

    address public devFund;
    address public uniRewardPool;
    address public yflRewardPool;
    address public drcRewardPool;
    address payable public drainController;

    /**
     * @notice Construct the contract
     * @param uniRewardPool_ address of the uniswap LP reward pool
     * @param yflRewardPool_ address of the linkswap LP reward pool
     * @param drcRewardPool_ address of the DRC->ETH reward pool
     */
    constructor(address weth_, address _devFund, address uniRewardPool_, address yflRewardPool_, address drcRewardPool_) {
        require((gasShare + devShare + uniRewardPoolShare + yflRewardPoolShare + drcRewardPoolShare) == 1000, "invalid distribution");
        uniRewardPool = uniRewardPool_;
        yflRewardPool = yflRewardPool_;
        drcRewardPool = drcRewardPool_;
        WETH = IWETH(weth_);
        devFund = _devFund;
        IWETH(weth_).approve(uniRewardPool, uint256(-1));
        IWETH(weth_).approve(yflRewardPool, uint256(-1));
        IWETH(weth_).approve(drcRewardPool, uint256(-1));
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    /**
     * @notice Distributes drained rewards
     */
    function distribute() external {
        require(drainController != address(0), "drainctrl not set");
        require(WETH.balanceOf(address(this)) >= wethThreshold, "weth balance too low");
        uint256 drainWethBalance = WETH.balanceOf(address(this));
        uint256 gasAmt = drainWethBalance.mul(gasShare).div(1000);
        uint256 devAmt = drainWethBalance.mul(devShare).div(1000);
        uint256 uniRewardPoolAmt = drainWethBalance.mul(uniRewardPoolShare).div(1000);
        uint256 yflRewardPoolAmt = drainWethBalance.mul(yflRewardPoolShare).div(1000);
        uint256 drcRewardPoolAmt = drainWethBalance.mul(drcRewardPoolShare).div(1000);

        // Unwrap WETH and transfer ETH to DrainController to cover drain gas fees
        WETH.withdraw(gasAmt);
        drainController.transfer(gasAmt);

        // Treasury
        WETH.transfer(devFund, devAmt);

        // Reward pools
        IRewardPool(uniRewardPool).fundPool(uniRewardPoolAmt);
        IRewardPool(yflRewardPool).fundPool(yflRewardPoolAmt);
        IRewardPool(drcRewardPool).fundPool(drcRewardPoolAmt);
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
        uint256 drcRewardPoolShare_)
        external
        onlyOwner
    {
        require((gasShare_ + devShare_ + uniRewardPoolShare_ + yflRewardPoolShare_ + drcRewardPoolShare_) == 1000, "invalid distribution");
        gasShare = gasShare_;
        devShare = devShare_;
        uniRewardPoolShare = uniRewardPoolShare_;
        yflRewardPoolShare = yflRewardPoolShare_;
        drcRewardPoolShare = drcRewardPoolShare_;
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
         WETH.approve(uniRewardPool, uint256(-1));
    }

    /**
     * @notice Changes the address of the linkswap LP reward pool
     * @param rewardPool_ the new address
     */
    function changeYFLRewardPool(address rewardPool_) external onlyOwner {
        require(rewardPool_ != address(0));
        yflRewardPool = rewardPool_;
        WETH.approve(yflRewardPool, uint256(-1));
    }

    /**
     * @notice Changes the address of the DRC->ETH reward pool
     * @param rewardPool_ the new address
     */
    function changeDRCRewardPool(address rewardPool_) external onlyOwner {
        require(rewardPool_ != address(0));
        drcRewardPool = rewardPool_;
        WETH.approve(drcRewardPool, uint256(-1));
    }

    /**
     * @notice Change the WETH distribute threshold
     */
    function setWETHThreshold(uint256 wethThreshold_) external onlyOwner {
        wethThreshold = wethThreshold_;
    }
}
