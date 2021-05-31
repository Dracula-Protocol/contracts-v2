// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

interface IArcherSwapRouter {

    struct Trade {
        uint amountIn;
        uint amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
    }

    /**
     * @notice Swap tokens for tokens and pay ETH amount as tip
     * @param router Uniswap V2-compliant Router contract
     * @param trade Trade details
     */
    function swapExactTokensForTokensWithTipAmount(
        address router,
        Trade calldata trade
    ) external payable;


    /**
     * @notice Swap tokens for tokens and pay % of tokens as tip
     * @param router Uniswap V2-compliant Router contract
     * @param trade Trade details
     * @param pathToEth Path to ETH for tip
     * @param minEth ETH minimum for tip conversion
     * @param tipPct % of resulting tokens to pay as tip
     */
    function swapExactTokensForTokensWithTipPct(
        address router,
        Trade calldata trade,
        address[] calldata pathToEth,
        uint256 minEth,
        uint32 tipPct
    ) external payable;
}