// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IMasterChef.sol";

contract PickleAdapter is BaseAdapter {
    IMasterChef constant pickleMasterChef = IMasterChef(0xbD17B1ce622d73bD438b9E658acA5996dc394b0d);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IERC20 constant pickle = IERC20(0x429881672B9AE42b8EbA0E26cD9C73711b891Ca5);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant pickleWethPair = IUniswapV2Pair(0x269Db91Fc3c7fCC275C2E6f22e5552504512811c);
    // token 0 - pickle
    // token 1 - weth

    // Victim info
    function rewardToken(uint256) public view override returns (IERC20) {
        return pickle;
    }

    function poolCount() external view override returns (uint256) {
        return pickleMasterChef.poolLength();
    }

    function sellableRewardAmount(uint256) external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        pickle.transfer(address(pickleWethPair), rewardAmount);
        (uint pickleReserve, uint wethReserve,) = pickleWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, pickleReserve, wethReserve);
        pickleWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = pickleMasterChef.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = pickleMasterChef.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return pickleMasterChef.pendingPickle(victimPoolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(pickleMasterChef), uint256(-1));
        pickleMasterChef.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override returns (uint256) {
        pickleMasterChef.withdraw(poolId, amount);
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        pickleMasterChef.deposit(victimPoolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        pickleMasterChef.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(pickleMasterChef);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(pickleWethPair);
    }

    function lockedValue(address, uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }

    function totalLockedValue(uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }

    function normalizedAPY(uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }
}
