// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "../../IMasterVampire.sol";
import "./ITrueFarm.sol";

contract TruefiAdapter is BaseAdapter, IMasterVampire {
    address immutable MASTER_VAMPIRE;
    IERC20 constant TRU = IERC20(0x4C19596f5aAfF459fA38B0f7eD92F11AE6543784);
    IUniswapV2Pair constant TRU_WETH_PAIR = IUniswapV2Pair(0xfCEAAf9792139BF714a694f868A215493461446D);
    ITrueFarm[] farms;

    constructor(address _weth, address _factory, address _masterVampire)
        BaseAdapter(_weth, _factory)
    {
        MASTER_VAMPIRE = _masterVampire;
        farms.push(ITrueFarm(0x8FD832757F58F71BAC53196270A4a55c8E1a29D9)); // TFI-LP farm
        farms.push(ITrueFarm(0xED45Cf4895C110f464cE857eBE5f270949eC2ff4)); // ETH/TRU farm
        farms.push(ITrueFarm(0xf8F14Fbb93fa0cEFe35Acf7e004fD4Ef92d8315a)); // TUSD/TFI-LP farm
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return TRU;
    }

    function poolCount() external view override returns (uint256) {
        return farms.length;
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        TRU.transfer(address(TRU_WETH_PAIR), rewardAmount);
        (uint truReserve, uint wethReserve,) = TRU_WETH_PAIR.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, truReserve, wethReserve);
        TRU_WETH_PAIR.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        return farms[poolId].stakingToken();
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        return farms[poolId].staked(user);
    }

    function pendingReward(address _adapter, uint256, uint256 victimPoolId) external view override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        ITrueFarm farm = ITrueFarm(adapter.poolAddress(victimPoolId));
        return farm.claimableReward(MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(farms[poolId]), uint256(-1));
        ITrueFarm(adapter.poolAddress(poolId)).stake(amount);
        return 0;
    }

    function withdraw(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        ITrueFarm(adapter.poolAddress(poolId)).unstake(amount);
        return 0;
    }

    function claimReward(address _adapter, uint256, uint256 victimPoolId) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        ITrueFarm(adapter.poolAddress(victimPoolId)).claim();
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(farms[poolId]);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(TRU_WETH_PAIR);
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