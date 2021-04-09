// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./IStakingPools.sol";

contract LuaAdapter is BaseAdapter {
    address constant MASTER_VAMPIRE =
        0x12B7b9e21Ad9D7E8992e0c129ED0bccEaC185c3E;
    IStakingPools constant ALCX_STAKINGPOOLS =
        IStakingPools(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    IERC20 constant ALCX = IERC20(0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF);
    IUniswapV2Pair constant ALCX_WETH_PAIR =
        IUniswapV2Pair(0x352E5EeE2D9C957710be656534D51Fbb3Ce074d6);

    constructor(address _weth, address _factory) BaseAdapter(_weth, _factory) {}

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return ALCX;
    }

    function poolCount() external view override returns (uint256) {
        return ALCX_STAKINGPOOLS.poolCount();
    }

    function sellableRewardAmount(uint256)
        external
        pure
        override
        returns (uint256)
    {
        return uint256(-1);
    }

    function sellRewardForWeth(
        address,
        uint256,
        uint256 rewardAmount,
        address to
    ) external override returns (uint256) {
        // ETH-ALCX Pair
        ALCX.transfer(address(ALCX_WETH_PAIR), rewardAmount);
        (uint256 wethReserve, uint256 alcxReserve, ) =
            ALCX_WETH_PAIR.getReserves();
        uint256 amountOutput =
            UniswapV2Library.getAmountOut(
                rewardAmount,
                wethReserve,
                alcxReserve
            );
        ALCX_WETH_PAIR.swap(amountOutput, uint256(0), to, new bytes(0));
        return amountOutput;
    }

    // Pool info
    function lockableToken(uint256 poolId)
        external
        view
        override
        returns (IERC20)
    {
        return ALCX_STAKINGPOOLS.getPoolToken(poolId);
    }

    function lockedAmount(address user, uint256 poolId)
        external
        view
        override
        returns (uint256)
    {
        return ALCX_STAKINGPOOLS.getStakeTotalDeposited(user, poolId);
    }

    function pendingReward(
        address,
        uint256,
        uint256 victimPoolId
    ) external view override returns (uint256) {
        return
            ALCX_STAKINGPOOLS.getStakeTotalUnclaimed(
                MASTER_VAMPIRE,
                victimPoolId
            );
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(
        address _adapter,
        uint256 poolId,
        uint256 amount
    ) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(
            address(ALCX_STAKINGPOOLS),
            uint256(-1)
        );
        ALCX_STAKINGPOOLS.deposit(poolId, amount);
        return 0;
    }

    function withdraw(
        address,
        uint256 poolId,
        uint256 amount
    ) external override returns (uint256) {
        ALCX_STAKINGPOOLS.withdraw(poolId, amount);
        return 0;
    }

    function claimReward(
        address,
        uint256,
        uint256 victimPoolId
    ) external override {
        ALCX_STAKINGPOOLS.claim(victimPoolId);
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256) external pure override returns (address) {
        return address(ALCX_STAKINGPOOLS);
    }

    function rewardToWethPool() external pure override returns (address) {
        return address(ALCX_WETH_PAIR);
    }

    function lockedValue(address, uint256)
        external
        pure
        override
        returns (uint256)
    {
        require(false, "not implemented");
        return 0;
    }

    function totalLockedValue(uint256)
        external
        pure
        override
        returns (uint256)
    {
        require(false, "not implemented");
        return 0;
    }

    function normalizedAPY(uint256) external pure override returns (uint256) {
        require(false, "not implemented");
        return 0;
    }
}
