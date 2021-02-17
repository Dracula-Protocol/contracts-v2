// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "./ILuaMasterFarmer.sol";

contract LuaAdapter is BaseAdapter {
    ILuaMasterFarmer constant luaMasterFarmer = ILuaMasterFarmer(0xb67D7a6644d9E191Cac4DA2B88D6817351C7fF62);
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IUniswapV2Router02 constant router = IUniswapV2Router02(0x1d5C6F1607A171Ad52EFB270121331b3039dD83e);
    IERC20 constant lua = IERC20(0xB1f66997A5760428D3a87D68b90BfE0aE64121cC);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Victim info
    function rewardToken(uint256) public override view returns (IERC20) {
        return lua;
    }

    function poolCount() external override view returns (uint256) {
        return luaMasterFarmer.poolLength();
    }

    function sellableRewardAmount(uint256) external override view returns (uint256) {
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
        (IERC20 lpToken, , , ) = luaMasterFarmer.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId)
        external
        override
        view
        returns (uint256)
    {
        (uint256 amount, , ) = luaMasterFarmer.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(address, uint256, uint256 victimPoolId) external view override returns (uint256) {
        return luaMasterFarmer.pendingReward(victimPoolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(
        address _adapter,
        uint256 poolId,
        uint256 amount
    ) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(luaMasterFarmer), uint256(-1));
        luaMasterFarmer.deposit(poolId, amount);
    }

    function withdraw(
        address,
        uint256 poolId,
        uint256 amount
    ) external override returns (uint256) {
        luaMasterFarmer.withdraw(poolId, amount);
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
        luaMasterFarmer.claimReward(victimPoolId);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        luaMasterFarmer.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external override view returns (address) {
        return address(luaMasterFarmer);
    }

    function rewardToWethPool() external override view returns (address) {
        return address(0);
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
