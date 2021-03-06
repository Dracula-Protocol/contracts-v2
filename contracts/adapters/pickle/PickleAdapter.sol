// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IMasterChef.sol";

contract PickleAdapter is BaseAdapter {
    IMasterChef constant PICKLE_MASTER_CHEF = IMasterChef(0xbD17B1ce622d73bD438b9E658acA5996dc394b0d);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IERC20 constant PICKLE = IERC20(0x429881672B9AE42b8EbA0E26cD9C73711b891Ca5);
    IUniswapV2Pair constant PICKLE_WETH_PAIR = IUniswapV2Pair(0x269Db91Fc3c7fCC275C2E6f22e5552504512811c);
    // token 0 - PICKLE
    // token 1 - weth

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return PICKLE;
    }

    function poolCount() external view override returns (uint256) {
        return PICKLE_MASTER_CHEF.poolLength();
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        PICKLE.transfer(address(PICKLE_WETH_PAIR), rewardAmount);
        (uint pickleReserve, uint wethReserve,) = PICKLE_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, pickleReserve, wethReserve);
        PICKLE_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = PICKLE_MASTER_CHEF.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = PICKLE_MASTER_CHEF.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return PICKLE_MASTER_CHEF.pendingPickle(victimPoolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(PICKLE_MASTER_CHEF), uint256(-1));
        PICKLE_MASTER_CHEF.deposit(poolId, amount);
        return 0;
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        PICKLE_MASTER_CHEF.withdraw(poolId, amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        PICKLE_MASTER_CHEF.deposit(victimPoolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        PICKLE_MASTER_CHEF.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external pure override returns (address) {
        return address(PICKLE_MASTER_CHEF);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(PICKLE_WETH_PAIR);
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
