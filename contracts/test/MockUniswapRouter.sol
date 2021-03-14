// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../libraries/UniswapV2Library.sol";
import "./MockUniswapFactory.sol";

interface IUniswapRouter {
    function factory() external view returns (address);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

contract MockUniswapRouter is IUniswapRouter {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable override factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) public override returns (uint256[] memory amounts) {
        return _swap(amountIn, amountOutMin, path, to, deadline);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        return _swap(amountIn, amountOutMin, path, to, deadline);
    }

    function _swap(
        uint256 amountIn,
        uint256,
        address[] calldata path,
        address to,
        uint256
    ) internal returns (uint256[] memory amounts) {
        uint256 amountOut = amountIn.mul(1); // assume 1 INPUT -> 1 OUTPUT
        IERC20 inputToken = IERC20(path[0]);
        IERC20 outputToken = IERC20(path[path.length - 1]);
        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);
        outputToken.safeTransfer(to, amountOut);
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint,
        uint,
        address to,
        uint
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        amountA = (amountADesired < amountBDesired) ? amountADesired : amountBDesired;
        amountB = amountA;
        require(pair != address(0), "pair doesn't exist");
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);

    }
}
