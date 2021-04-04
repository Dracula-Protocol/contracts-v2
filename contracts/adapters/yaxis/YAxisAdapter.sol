// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IYAxisMaster.sol";

contract YAxisAdapter is BaseAdapter {
    address constant MASTER_VAMPIRE = 0x12B7b9e21Ad9D7E8992e0c129ED0bccEaC185c3E;
    IYAxisMaster constant YAXIS_MASTER = IYAxisMaster(0xC330E7e73717cd13fb6bA068Ee871584Cf8A194F);
    IERC20 constant YAX = IERC20(0xb1dC9124c395c1e97773ab855d66E879f053A289);
    IUniswapV2Pair constant YAX_WETH_PAIR = IUniswapV2Pair(0x1107B6081231d7F256269aD014bF92E041cb08df);
    // token 0 - YAX
    // token 1 - WETH

    constructor(address _weth, address _factory)
        BaseAdapter(_weth, _factory)
    {
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return YAX;
    }

    function poolCount() external view override returns (uint256) {
        return YAXIS_MASTER.poolLength();
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        YAX.transfer(address(YAX_WETH_PAIR), rewardAmount);
        (uint yaxisReserve, uint wethReserve,) = YAX_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, yaxisReserve, wethReserve);
        YAX_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = YAXIS_MASTER.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = YAXIS_MASTER.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return YAXIS_MASTER.pendingYaxis(victimPoolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(YAXIS_MASTER), uint256(-1));
        YAXIS_MASTER.deposit(poolId, amount);
        return 0;
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        YAXIS_MASTER.withdraw(poolId, amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        YAXIS_MASTER.deposit(victimPoolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        YAXIS_MASTER.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external pure override returns (address) {
        return address(YAXIS_MASTER);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(YAX_WETH_PAIR);
    }

    function lockedValue(address, uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }

    function totalLockedValue(uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }

    function normalizedAPY(uint256) external override pure returns (uint256) {
        require(false, "not implemented");
        return 0;
    }
}
