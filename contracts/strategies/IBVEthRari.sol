// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../interfaces/IRariFundManager.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../libraries/UniswapV2Library.sol";
import "../IMasterVampire.sol";
import "../IIBVEth.sol";

/**
* @title Rari Capital ETH Strategy
*/
contract IBVEthRari is IIBVEth, IMasterVampire {
    using SafeMath for uint256;

    IRariFundManager private constant FUND_MANAGER = IRariFundManager(0xD6e194aF3d9674b62D1b30Ec676030C23961275e);
    IUniswapV2Pair private immutable drcWethPair;
    IERC20 private immutable dracula;

    constructor(address _dracula) {
        dracula = IERC20(_dracula);
        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        drcWethPair = IUniswapV2Pair(uniswapFactory.getPair(address(WETH), _dracula));
    }

    function handleDrainedWETH(uint256 amount) external override {
        WETH.withdraw(amount);
        FUND_MANAGER.deposit{value: amount}();
    }

    function handleClaim(uint256 pending, uint8 flag) external override {
        // Convert REPT into ETH for withdrawal
        pending = ibETHValue(pending);
        uint256 _before = address(this).balance;
        FUND_MANAGER.withdraw(pending);
        uint256 _after = address(this).balance;
        // Ensure withdrawn amount is not slightly off the calculated pending value
        pending = _after.sub(_before);

        if ((flag & 0x2) == 0) {
            _safeETHTransfer(msg.sender, pending);
        } else {
            WETH.deposit{value: pending}();
            address token0 = drcWethPair.token0();
            (uint reserve0, uint reserve1,) = drcWethPair.getReserves();
            (uint reserveInput, uint reserveOutput) = address(WETH) == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            uint amountOutput = UniswapV2Library.getAmountOut(pending, reserveInput, reserveOutput);
            (uint amount0Out, uint amount1Out) = address(WETH) == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));

            WETH.transfer(address(drcWethPair), pending);
            drcWethPair.swap(amount0Out, amount1Out, address(this), new bytes(0));
            dracula.transfer(msg.sender, amountOutput);
        }
    }

    function migrate() external pure override {
        require(false, "not implemented");
    }

    function ibToken() external view override returns(IERC20) {
        return FUND_MANAGER.rariFundToken();
    }

    function balance(address account) external view override returns(uint256) {
        return FUND_MANAGER.rariFundToken().balanceOf(account);
    }

    function ethBalance(address account) external override returns(uint256) {
        return FUND_MANAGER.balanceOf(account);
    }

    function ibETHValue(uint256 amount) public override returns (uint256) {
        IERC20 rariFundToken = FUND_MANAGER.rariFundToken();
        uint256 reptTotalSupply = rariFundToken.totalSupply();
        if (reptTotalSupply == 0) {
            return 0;
        }
        uint256 fundBalance = FUND_MANAGER.getFundBalance();
        uint256 accountBalance = amount.mul(fundBalance).div(reptTotalSupply);
        return accountBalance;
    }
}
