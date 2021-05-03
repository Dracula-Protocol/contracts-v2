// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IMasterChef.sol";


interface ISushiBar is IERC20 {
    function enter(uint256 amount) external;
}

contract SushiAdapter is BaseAdapter {
    using SafeMath for uint256;
    IMasterChef constant SUSHI_MASTER_CHEF = IMasterChef(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd);
    address immutable MASTER_VAMPIRE;
    address constant DEV_FUND = 0xa896e4bd97a733F049b23d2AcEB091BcE01f298d;
    IERC20 constant SUSHI = IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    ISushiBar constant SUSHI_BAR = ISushiBar(0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272);
    IUniswapV2Pair constant SUSHI_WETH_PAIR = IUniswapV2Pair(0x795065dCc9f64b5614C407a6EFDC400DA6221FB0);
    uint256 constant BLOCKS_PER_YEAR = 2336000;
    uint256 constant DEV_SHARE = 20; // 2%
    // token 0 - SUSHI
    // token 1 - WETH

    constructor(address _weth, address _factory, address _masterVampire)
        BaseAdapter(_weth, _factory)
    {
        MASTER_VAMPIRE = _masterVampire;
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return SUSHI;
    }

    function poolCount() external view override returns (uint256) {
        return SUSHI_MASTER_CHEF.poolLength();
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        uint256 devAmt = rewardAmount.mul(DEV_SHARE).div(1000);
        SUSHI.approve(address(SUSHI_BAR), devAmt);
        SUSHI_BAR.enter(devAmt);
        SUSHI_BAR.transfer(DEV_FUND, SUSHI_BAR.balanceOf(address(this)));
        rewardAmount = rewardAmount.sub(devAmt);

        SUSHI.transfer(address(SUSHI_WETH_PAIR), rewardAmount);
        (uint sushiReserve, uint wethReserve,) = SUSHI_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, sushiReserve, wethReserve);
        SUSHI_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 victimPID) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = SUSHI_MASTER_CHEF.poolInfo(victimPID);
        return lpToken;
    }

    function lockedAmount(address user, uint256 victimPID) external view override returns (uint256) {
        (uint256 amount,) = SUSHI_MASTER_CHEF.userInfo(victimPID, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPID) external view override returns (uint256) {
        return SUSHI_MASTER_CHEF.pendingSushi(victimPID, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 victimPID, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(victimPID).approve(address(SUSHI_MASTER_CHEF), uint256(-1));
        SUSHI_MASTER_CHEF.deposit(victimPID, amount);
        return 0;
    }

    function withdraw(address, uint256 victimPID, uint256 amount) external override returns (uint256) {
        SUSHI_MASTER_CHEF.withdraw(victimPID, amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPID) external override {
        SUSHI_MASTER_CHEF.deposit(victimPID, 0);
    }

    function emergencyWithdraw(address, uint256 victimPID) external override {
        SUSHI_MASTER_CHEF.emergencyWithdraw(victimPID);
    }

    // Service methods
    function poolAddress(uint256) external pure override returns (address) {
        return address(SUSHI_MASTER_CHEF);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(SUSHI_WETH_PAIR);
    }

    function lockedValue(address user, uint256 victimPID) external override view returns (uint256) {
        SushiAdapter adapter = SushiAdapter(this);
        return adapter.lpTokenValue(adapter.lockedAmount(user, victimPID),IUniswapV2Pair(address(adapter.lockableToken(victimPID))));
    }

    function totalLockedValue(uint256 victimPID) external override view returns (uint256) {
        SushiAdapter adapter = SushiAdapter(this);
        IUniswapV2Pair lockedToken = IUniswapV2Pair(address(adapter.lockableToken(victimPID)));
        return adapter.lpTokenValue(lockedToken.balanceOf(adapter.poolAddress(victimPID)), lockedToken);
    }

    function normalizedAPY(uint256 victimPID) external override view returns (uint256) {
        SushiAdapter adapter = SushiAdapter(this);
        (,uint256 allocationPoints,,) = SUSHI_MASTER_CHEF.poolInfo(victimPID);
        uint256 sushiPerBlock = SUSHI_MASTER_CHEF.sushiPerBlock();
        uint256 totalAllocPoint = SUSHI_MASTER_CHEF.totalAllocPoint();
        uint256 multiplier = SUSHI_MASTER_CHEF.getMultiplier(block.number - 1, block.number);
        uint256 rewardPerBlock = multiplier.mul(sushiPerBlock).mul(allocationPoints).div(totalAllocPoint);
        (uint256 sushiReserve, uint256 wethReserve,) = SUSHI_WETH_PAIR.getReserves();
        uint256 valuePerYear = rewardPerBlock.mul(wethReserve).mul(BLOCKS_PER_YEAR).div(sushiReserve);
        return valuePerYear.mul(1 ether).div(adapter.totalLockedValue(victimPID));
    }
}
