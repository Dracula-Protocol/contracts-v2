// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IOperator.sol";

contract StabilizeAdapter is BaseAdapter {
    using SafeMath for uint256;
    IOperator constant OPERATOR = IOperator(0xEe9156C93ebB836513968F92B4A67721f3cEa08a);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IERC20 constant STBZ = IERC20(0xB987D48Ed8f2C468D52D6405624EADBa5e76d723);
    IUniswapV2Pair constant STBZ_WETH_PAIR = IUniswapV2Pair(0xDB28312a8d26D59978D9B86cA185707B1A26725b);
    uint256 constant BLOCKS_PER_YEAR = 2336000;
    // token 0 - stbz
    // token 1 - weth

    constructor(address _weth, address _factory)
        BaseAdapter(_weth, _factory)
    {
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return STBZ;
    }

    function poolCount() external view override returns (uint256) {
        return OPERATOR.poolLength();
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        STBZ.transfer(address(STBZ_WETH_PAIR), rewardAmount);
        (uint stbzReserve, uint wethReserve,) = STBZ_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, stbzReserve, wethReserve);
        STBZ_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,,,,,,) = OPERATOR.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,,) = OPERATOR.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return OPERATOR.rewardEarned(victimPoolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(OPERATOR), uint256(-1));
        OPERATOR.deposit(poolId, amount);
        return 0;
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        OPERATOR.withdraw(poolId, amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        OPERATOR.getReward(victimPoolId);
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256) external pure override returns (address) {
        return address(OPERATOR);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(STBZ_WETH_PAIR);
    }

    function lockedValue(address user, uint256 poolId) external override view returns (uint256) {
        StabilizeAdapter adapter = StabilizeAdapter(this);
        return adapter.lpTokenValue(adapter.lockedAmount(user, poolId),IUniswapV2Pair(address(adapter.lockableToken(poolId))));
    }

    function totalLockedValue(uint256 poolId) external override view returns (uint256) {
        StabilizeAdapter adapter = StabilizeAdapter(this);
        IUniswapV2Pair lockedToken = IUniswapV2Pair(address(adapter.lockableToken(poolId)));
        return adapter.lpTokenValue(lockedToken.balanceOf(adapter.poolAddress(poolId)), lockedToken);
    }

    function normalizedAPY(uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }
}
