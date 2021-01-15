// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../IVampireAdapter.sol";
import "./IMasterChef.sol";

contract SashimiAdapter is IVampireAdapter {
    address constant MASTER_VAMPIRE = 0xD12d68Fd52b54908547ebC2Cd77Ec6EbbEfd3099;
    IMasterChef constant SASHIMI_MASTERCHEF = IMasterChef(0x1DaeD74ed1dD7C9Dabbe51361ac90A69d851234D);
    IUniswapV2Router02 constant router = IUniswapV2Router02(0xe4FE6a45f354E845F954CdDeE6084603CEDB9410);
    IERC20 constant SASHIMI = IERC20(0xC28E27870558cF22ADD83540d2126da2e4b464c2);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Victim info
    function rewardToken(uint256) external view override returns (IERC20) {
        return SASHIMI;
    }

    function poolCount() external view override returns (uint256) {
        return SASHIMI_MASTERCHEF.poolLength();
    }

    function sellableRewardAmount(uint256) external view override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256 rewardAmount, address to) external override returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = address(SASHIMI);
        path[1] = address(WETH);
        uint[] memory amounts = router.getAmountsOut(rewardAmount, path);
        SASHIMI.approve(address(router), rewardAmount);
        amounts = router.swapExactTokensForTokens(rewardAmount, amounts[amounts.length - 1], path, to, block.timestamp);
        return amounts[amounts.length - 1];
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = SASHIMI_MASTERCHEF.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = SASHIMI_MASTERCHEF.userInfo(poolId, user);
        return amount;
    }

    function pendingReward(uint256 poolId) external view override returns (uint256) {
        return SASHIMI_MASTERCHEF.pendingSashimi(poolId, MASTER_VAMPIRE);
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(SASHIMI_MASTERCHEF), uint256(-1));
        SASHIMI_MASTERCHEF.deposit(poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        SASHIMI_MASTERCHEF.withdraw(poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        SASHIMI_MASTERCHEF.deposit(poolId, 0);
    }

    function emergencyWithdraw(address, uint256 poolId) external override {
        SASHIMI_MASTERCHEF.emergencyWithdraw(poolId);
    }

    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(SASHIMI_MASTERCHEF);
    }

    function rewardToWethPool() external view override returns (address) {
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
