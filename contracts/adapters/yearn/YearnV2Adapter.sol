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
    IERC20[] underlyingVaultTokens;

    constructor(address _weth, address _factory, address _masterVampire, address[] memory vaults_, address[] memory underlyingTokens)
        BaseAdapter(_weth, _factory)
    {
        MASTER_VAMPIRE = IMasterVampire(_masterVampire);
        for (uint i = 0; i < vaults_.length; i++) {
            vaults.push(IYearnV2Vault(vaults_[i]));
        }
        for (uint i = 0; i < underlyingTokens.length; i++) {
            underlyingVaultTokens.push(IERC20(underlyingTokens[i]));
        }
        /*vaults.push(IYearnV2Vault(0xa9fE4601811213c340e850ea305481afF02f5b28)); // WETH
        vaults.push(IYearnV2Vault(0xE14d13d8B3b85aF791b2AADD661cDBd5E6097Db1)); // YFI
        vaults.push(IYearnV2Vault(0xA696a63cc78DfFa1a63E9E50587C197387FF6C7E)); // WBTC
        vaults.push(IYearnV2Vault(0x19D3364A399d251E894aC732651be8B0E4e85001)); // DAI
        vaults.push(IYearnV2Vault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9)); // USDC
        vaults.push(IYearnV2Vault(0x7Da96a3891Add058AdA2E826306D812C638D87a7)); // USDT
        vaults.push(IYearnV2Vault(0xF29AE508698bDeF169B89834F76704C3B205aedf)); // SNX
        vaults.push(IYearnV2Vault(0xFBEB78a723b8087fD2ea7Ef1afEc93d35E8Bed42)); // UNI
        vaults.push(IYearnV2Vault(0xB8C3B7A2A618C552C23B1E4701109a9E756Bab67)); // 1INCH
        vaults.push(IYearnV2Vault(0x25212Df29073FfFA7A67399AcEfC2dd75a831A1A)); // crvEURS
        vaults.push(IYearnV2Vault(0x39CAF13a104FF567f71fd2A4c68C026FDB6E740B)); // crvAAVE
        vaults.push(IYearnV2Vault(0xD6Ea40597Be05c201845c0bFd2e96A60bACde267)); // crvCOMP
        vaults.push(IYearnV2Vault(0xB4AdA607B9d6b2c9Ee07A275e9616B84AC560139)); // crvFRAX
        vaults.push(IYearnV2Vault(0x8cc94ccd0f3841a468184aCA3Cc478D2148E1757)); // crvMUSD
        vaults.push(IYearnV2Vault(0xf8768814b88281DE4F532a3beEfA5b85B69b9324)); // crvTUSD
        vaults.push(IYearnV2Vault(0x3B96d491f067912D18563d56858Ba7d6EC67a6fa)); // crvUSDN
        vaults.push(IYearnV2Vault(0xC4dAf3b5e2A9e93861c3FBDd25f1e943B8D87417)); // crvUSDP
        vaults.push(IYearnV2Vault(0x1C6a9783F812b3Af3aBbf7de64c3cD7CC7D1af44)); // crvUST
        vaults.push(IYearnV2Vault(0x132d8D2C76Db3812403431fAcB00F3453Fc42125)); // crvAETH
        vaults.push(IYearnV2Vault(0xBfedbcbe27171C418CDabC2477042554b1904857)); // crvRETH
        vaults.push(IYearnV2Vault(0x3c5DF3077BcF800640B5DAE8c91106575a4826E6)); // crvPBTC*/
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
        return underlyingVaultTokens[poolId];
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
