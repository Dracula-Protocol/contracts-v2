// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../BaseAdapter.sol";
import "../../interfaces/IYearnV2.sol";

interface IMasterVampire {
    function userInfo(uint256 pid, address user) external view returns (uint256 amount,
                                                                        uint256 rewards,
                                                                        uint256 rewardDebt,
                                                                        uint256 poolShares);
}

contract YearnV2Adapter is BaseAdapter {
    using SafeMath for uint256;
    IMasterVampire immutable MASTER_VAMPIRE;
    IYearnV2Vault[] vaults;

    constructor(address _weth, address _factory, address _masterVampire, address[] memory vaults_)
        BaseAdapter(_weth, _factory)
    {
        MASTER_VAMPIRE = IMasterVampire(_masterVampire);
        for (uint i = 0; i < vaults_.length; i++) {
            vaults.push(IYearnV2Vault(vaults_[i]));
        }
    }

    // Victim info
    function rewardToken(uint256) public pure override returns (IERC20) {
        return IERC20(0);
    }

    function poolCount() external view override returns (uint256) {
        return vaults.length;
    }

    function sellableRewardAmount(uint256) external pure override returns (uint256) {
        return uint256(-1);
    }

    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256, uint256, address) external pure override returns(uint256) {
        return 0;
    }

    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        return IERC20(vaults[poolId].token());
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        IYearnV2Vault vault = vaults[poolId];
        (,,, uint256 poolShares) = MASTER_VAMPIRE.userInfo(poolId, user);
        uint256 pricePerShare = vault.pricePerShare();
        if (pricePerShare == 0) {
            return 0;
        }
        return poolShares.mul(1e18).div(pricePerShare);
    }

    function pendingReward(address, uint256, uint256) external view override returns (uint256) {
        return 0;
    }

    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IYearnV2Vault vault = IYearnV2Vault(adapter.poolAddress(poolId));
        adapter.lockableToken(poolId).approve(address(vault), uint256(-1));

        uint256 _before = vault.balanceOf(address(this));
        vault.deposit(amount);
        uint256 _after = vault.balanceOf(address(this));
        return _after.sub(_before);
    }

    function withdraw(address _adapter, uint256 poolId, uint256 amount) external override returns (uint256) {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        IYearnV2Vault vault = IYearnV2Vault(adapter.poolAddress(poolId));
        vault.withdraw(amount);
        return 0;
    }

    function claimReward(address, uint256, uint256 victimPoolId) external override {
       // not implemented for vaults
    }

    function emergencyWithdraw(address, uint256) external pure override {
        require(false, "not implemented");
    }

    // Service methods
    function poolAddress(uint256 poolId) external view override returns (address) {
        return address(vaults[poolId]);
    }

    function rewardToWethPool() external pure override returns (address) {
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
