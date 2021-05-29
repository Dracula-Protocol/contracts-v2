// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../libraries/UniswapV2Library.sol";
import "./MockUniswapRouter.sol";

contract MockArcherSwapRouter is MockUniswapRouter {

    /// @notice Trade details
    struct Trade {
        uint amountIn;
        uint amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
    }

    constructor(address _factory) MockUniswapRouter(_factory) {
    }

    /**
     * @notice Swap tokens for tokens and pay % of tokens as tip
     * @param trade Trade details
     */
    function swapExactTokensForTokensWithTipPct(
        address /*router*/,
        Trade calldata trade,
        address[] calldata /*pathToEth*/,
        uint256 /*minEth*/,
        uint32 /*tipPct*/
    ) external payable {
        swapExactTokensForTokens(trade.amountIn, trade.amountOut, trade.path, trade.to, trade.deadline);
    }
}