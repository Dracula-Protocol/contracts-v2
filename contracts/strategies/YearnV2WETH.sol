// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../interfaces/IYearnV2.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../libraries/UniswapV2Library.sol";
import "../IMasterVampire.sol";
import "../IIBVEth.sol";

/**
* @title YearnV2 WETH Vault
*/
contract YearnV2WETH is IIBVEth, IMasterVampire {
    using SafeMath for uint256;
    using SafeERC20 for IWETH;

    IYearnV2Vault private immutable vault;
    IUniswapV2Pair private immutable drcWethPair;
    IERC20 private immutable dracula;

    constructor(
        address _dracula,
        address _weth,
        address _swapFactory,
        address _yvToken)
        IIBVEth(_weth)
    {
        dracula = IERC20(_dracula);
        IUniswapV2Factory swapFactory = IUniswapV2Factory(_swapFactory);
        drcWethPair = IUniswapV2Pair(swapFactory.getPair(_weth, _dracula));
        vault = IYearnV2Vault(_yvToken);
    }

    function handleDrainedWETH(uint256 amount) external override {
        WETH.safeApprove(address(vault), amount);
        vault.deposit(amount);
    }

    function handleClaim(uint256 pendingShares, uint256 tipAmount, uint8 flag) external payable override {
        uint256 _wethBefore = WETH.balanceOf(address(this));
        vault.withdraw(pendingShares);
        uint256 _wethAfter = WETH.balanceOf(address(this));
        // Ensure withdrawn amount is not slightly off the calculated pending value
        uint256 pendingWETH = _wethAfter.sub(_wethBefore);

        if ((flag & 0x2) == 0) {
            WETH.safeTransfer(msg.sender, pendingWETH);
        } else {
            address token0 = drcWethPair.token0();
            (uint reserve0, uint reserve1,) = drcWethPair.getReserves();
            (uint reserveInput, uint reserveOutput) = address(WETH) == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            uint amountOutput = UniswapV2Library.getAmountOut(pendingWETH, reserveInput, reserveOutput);
            (uint amount0Out, uint amount1Out) = address(WETH) == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));

            WETH.transfer(address(drcWethPair), pendingWETH);
            drcWethPair.swap(amount0Out, amount1Out, msg.sender, new bytes(0));
            // Tip the Archer miners
            block.coinbase.call{value: tipAmount}("");
        }
    }

    function migrate() external pure override {
        require(false, "not implemented");
    }

    function ibToken() external view override returns(IERC20) {
        return vault;
    }

    function balance(address account) external view override returns(uint256) {
        return vault.balanceOf(account);
    }

    function ethBalance(address account) external override returns(uint256) {
        uint256 totalShares = vault.balanceOf(account);
        return totalShares.mul(1e18).div(vault.pricePerShare());
    }

    function ibETHValue(uint256 shares) public override returns (uint256) {
        return shares.mul(1e18).div(vault.pricePerShare());
    }
}
