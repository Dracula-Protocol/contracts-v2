// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IWETH.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";

interface IRewardPool {
    function fundPool(uint256 reward) external;
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
    uint256 public treasuryShare = 250;
    uint256 public lpRewardPoolShare = 400;
    uint256 public drcRewardPoolShare = 250;
    uint256 public wethThreshold = 200000000000000000 wei;

    address public immutable drc;
    address public treasury;
    address public lpRewardPool;
    address payable public drcRewardPool;
    address payable public drainController;

    IUniswapV2Router02 public immutable swapRouter;

    /**
     * @notice Construct the contract
     * @param lpRewardPool_ address of the uniswap LP reward pool
     * @param drcRewardPool_ address of the DRC reward pool
     */
    constructor(
        address weth_,
        address drc_,
        address _treasury,
        address lpRewardPool_,
        address payable drcRewardPool_,
        address swapRouter_)
    {
        require((gasShare + treasuryShare + lpRewardPoolShare + drcRewardPoolShare) == 1000, "invalid distribution");
        lpRewardPool = lpRewardPool_;
        drcRewardPool = drcRewardPool_;
        swapRouter = IUniswapV2Router02(swapRouter_);
        WETH = IWETH(weth_);
        drc = drc_;
        treasury = _treasury;
        IWETH(weth_).approve(lpRewardPool, uint256(-1));
        IWETH(weth_).approve(swapRouter_, uint256(-1));
    }

    /**
     * @notice Allow depositing ether to the contract
     */
    receive() external payable {}

    /**
     * @notice Distributes drained rewards
     */
    function distribute(uint256 tipAmount) external payable {
        require(drainController != address(0), "drainctrl not set");
        require(WETH.balanceOf(address(this)) >= wethThreshold, "weth balance too low");
        uint256 drainWethBalance = WETH.balanceOf(address(this));
        uint256 gasAmt = drainWethBalance.mul(gasShare).div(1000);
        uint256 devAmt = drainWethBalance.mul(treasuryShare).div(1000);
        uint256 lpRewardPoolAmt = drainWethBalance.mul(lpRewardPoolShare).div(1000);
        uint256 drcRewardPoolAmt = drainWethBalance.mul(drcRewardPoolShare).div(1000);

        // Unwrap WETH and transfer ETH to DrainController to cover drain gas fees
        WETH.withdraw(gasAmt);
        drainController.transfer(gasAmt);

        // Treasury
        WETH.transfer(treasury, devAmt);

        // Reward pools
        IRewardPool(lpRewardPool).fundPool(lpRewardPoolAmt);

        // Buy-back
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = drc;

        if (tipAmount > 0) {
            (bool success, ) = block.coinbase.call{value: tipAmount}("");
            require(success, "Could not tip miner");
        }

        uint[] memory amounts = swapRouter.getAmountsOut(drcRewardPoolAmt, path);
        swapRouter.swapExactTokensForTokens(drcRewardPoolAmt, amounts[amounts.length - 1], path, drcRewardPool, block.timestamp);
    }

    /**
     * @notice Changes the distribution percentage
     *         Percentages are using decimal base of 1000 ie: 10% = 100
     */
    function changeDistribution(
        uint256 gasShare_,
        uint256 treasuryShare_,
        uint256 lpRewardPoolShare_,
        uint256 drcRewardPoolShare_)
        external
        onlyOwner
    {
        require((gasShare_ + treasuryShare_ + lpRewardPoolShare_ + drcRewardPoolShare_) == 1000, "invalid distribution");
        gasShare = gasShare_;
        treasuryShare = treasuryShare_;
        lpRewardPoolShare = lpRewardPoolShare_;
        drcRewardPoolShare = drcRewardPoolShare_;
    }

    /**
     * @notice Changes the address of the treasury
     * @param treasury_ the new address
     */
    function changeTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0));
        treasury = treasury_;
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
    function changeLPRewardPool(address rewardPool_) external onlyOwner {
        require(rewardPool_ != address(0));
        lpRewardPool = rewardPool_;
        WETH.approve(lpRewardPool, uint256(-1));
    }

    /**
     * @notice Changes the address of the DRC->ETH reward pool
     * @param rewardPool_ the new address
     */
    function changeDRCRewardPool(address payable rewardPool_) external onlyOwner {
        require(rewardPool_ != address(0));
        drcRewardPool = rewardPool_;
    }

    /**
     * @notice Change the WETH distribute threshold
     */
    function setWETHThreshold(uint256 wethThreshold_) external onlyOwner {
        wethThreshold = wethThreshold_;
    }
}
