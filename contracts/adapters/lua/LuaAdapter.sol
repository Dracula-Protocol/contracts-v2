// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./ILuaMasterFarmer.sol";

contract LuaAdapter is BaseAdapter {
    ILuaMasterFarmer constant LUA_MASTER_FARMER = ILuaMasterFarmer(0xb67D7a6644d9E191Cac4DA2B88D6817351C7fF62);
    address immutable MASTER_VAMPIRE;
    IUniswapV2Router02 constant router = IUniswapV2Router02(0x1d5C6F1607A171Ad52EFB270121331b3039dD83e);
    IERC20 constant lua = IERC20(0xB1f66997A5760428D3a87D68b90BfE0aE64121cC);

    constructor(address _weth, address _factory, address _masterVampire)
        BaseAdapter(_weth, _factory)
    {
        MASTER_VAMPIRE = _masterVampire;
    }

    // Victim info
    function rewardToken(uint256) public override pure returns (IERC20) {
        return lua;
    }

    function poolCount() external override view returns (uint256) {
        return LUA_MASTER_FARMER.poolLength();
    }

    function sellableRewardAmount(uint256) external override pure returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(
        address,
        uint256,
        uint256 rewardAmount,
        address to
    ) external override returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(lua);
        path[1] = address(weth);
        uint[] memory amounts = router.getAmountsOut(rewardAmount, path);
        lua.approve(address(router), uint256(-1));
        amounts = router.swapExactTokensForTokens(rewardAmount, amounts[amounts.length - 1], path, to, block.timestamp);
        return amounts[amounts.length - 1];
    }

    // Pool info
    function lockableToken(uint256 poolId)
        external
        override
        view
        returns (IERC20)
    {
        (IERC20 lpToken, , , ) = LUA_MASTER_FARMER.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId)
        external
        override
        view
        returns (uint256)
    {
        (uint256 amount, , ) = LUA_MASTER_FARMER.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return LUA_MASTER_FARMER.pendingReward(victimPoolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(
        address _adapter,
        uint256 poolId,
        uint256 amount
    ) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(LUA_MASTER_FARMER), uint256(-1));
        LUA_MASTER_FARMER.deposit(poolId, amount);
        return 0;
    }

    function withdraw(
        address,
        uint256 poolId,
        uint256 amount
    ) external override returns (uint256) {
        LUA_MASTER_FARMER.withdraw(poolId, amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        LUA_MASTER_FARMER.claimReward(victimPoolId);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        LUA_MASTER_FARMER.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external override pure returns (address) {
        return address(LUA_MASTER_FARMER);
    }

    function rewardToWethPool() external override pure returns (address) {
        return address(0);
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
