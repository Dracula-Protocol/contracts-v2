// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "./IOperator.sol";

contract StabilizeAdapter is IVampireAdapter {
    using SafeMath for uint256;
    IOperator constant OPERATOR = IOperator(0xEe9156C93ebB836513968F92B4A67721f3cEa08a);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IERC20 constant STBZ = IERC20(0xB987D48Ed8f2C468D52D6405624EADBa5e76d723);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant STBZ_WETH_PAIR = IUniswapV2Pair(0xDB28312a8d26D59978D9B86cA185707B1A26725b);
    uint256 constant BLOCKS_PER_YEAR = 2336000;
    // token 0 - stbz
    // token 1 - weth

    // Victim info
    function rewardToken(uint256) external view override returns (IERC20) {
        return STBZ;
    }

    function poolCount() external view override returns (uint256) {
        return OPERATOR.poolLength();
    }

    function sellableRewardAmount(uint256) external view override returns (uint256) {
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

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return OPERATOR.rewardEarned(poolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(OPERATOR), uint256(-1));
        OPERATOR.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        OPERATOR.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        OPERATOR.getReward(poolId);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(OPERATOR);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(STBZ_WETH_PAIR);
    }

    function lpTokenValue(uint256 amount, IUniswapV2Pair lpToken) public view returns(uint256) {
        (uint256 token0Reserve, uint256 token1Reserve,) = lpToken.getReserves();
        address token0 = lpToken.token0();
        address token1 = lpToken.token1();
        if (token0 == address(WETH)) {
            return amount.mul(token0Reserve).mul(2).div(lpToken.totalSupply());
        }

        if (token1 == address(WETH)) {
            return amount.mul(token1Reserve).mul(2).div(lpToken.totalSupply());
        }

        if (IUniswapV2Factory(lpToken.factory()).getPair(token0, address(WETH)) != address(0)) {
            (uint256 wethReserve, uint256 token0ToWethReserve) = UniswapV2Library.getReserves(lpToken.factory(), address(WETH), token0);
            uint256 tmp = amount.mul(token0Reserve).mul(wethReserve).mul(2);
            return tmp.div(token0ToWethReserve).div(lpToken.totalSupply());
        }

        require(
            IUniswapV2Factory(lpToken.factory()).getPair(token1, address(WETH)) != address(0),
            "Neither token0-weth nor token1-weth pair exists");
        (uint256 wethReserve, uint256 token1ToWethReserve) = UniswapV2Library.getReserves(lpToken.factory(), address(WETH), token1);
        uint256 tmp = amount.mul(token1Reserve).mul(wethReserve).mul(2);
        return tmp.div(token1ToWethReserve).div(lpToken.totalSupply());
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

    function normalizedAPY(uint256 poolId) external override view returns (uint256) {
        require(false, "not implemented");
    }
}
