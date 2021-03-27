// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./libraries/UniswapV2Library.sol";
import "./IVampireAdapter.sol";

abstract contract BaseAdapter is IVampireAdapter {
    using SafeMath for uint256;

    IERC20 immutable weth;
    IUniswapV2Factory immutable factory;

    constructor(address _weth, address _factory) {
        weth = IERC20(_weth);
        factory = IUniswapV2Factory(_factory);
    }

    /**
     * @notice Calculates the WETH value of an LP token
     */
    function lpTokenValue(uint256 amount, IUniswapV2Pair lpToken) public virtual override view returns(uint256) {
        (uint256 token0Reserve, uint256 token1Reserve,) = lpToken.getReserves();
        address token0 = lpToken.token0();
        address token1 = lpToken.token1();
        if (token0 == address(weth)) {
            return amount.mul(token0Reserve).mul(2).div(lpToken.totalSupply());
        }

        if (token1 == address(weth)) {
            return amount.mul(token1Reserve).mul(2).div(lpToken.totalSupply());
        }

        if (IUniswapV2Factory(lpToken.factory()).getPair(token0, address(weth)) != address(0)) {
            (uint256 wethReserve0, uint256 token0ToWethReserve0) = UniswapV2Library.getReserves(lpToken.factory(), address(weth), token0);
            uint256 tmp0 = amount.mul(token0Reserve).mul(wethReserve0).mul(2);
            return tmp0.div(token0ToWethReserve0).div(lpToken.totalSupply());
        }

        require(
            IUniswapV2Factory(lpToken.factory()).getPair(token1, address(weth)) != address(0),
            "Neither token0-weth nor token1-weth pair exists");
        (uint256 wethReserve1, uint256 token1ToWethReserve1) = UniswapV2Library.getReserves(lpToken.factory(), address(weth), token1);
        uint256 tmp1 = amount.mul(token1Reserve).mul(wethReserve1).mul(2);
        return tmp1.div(token1ToWethReserve1).div(lpToken.totalSupply());
    }

    /**
     * @notice Calculates the WETH value for an amount of pool reward token
     */
    function rewardValue(uint256 poolId, uint256 amount) external virtual override view returns(uint256) {
        address token = address(rewardToken(poolId));

        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(address(token), address(weth)));
        if (address(pair) != address(0)) {
                (uint tokenReserve0, uint wethReserve0,) = pair.getReserves();
                return UniswapV2Library.getAmountOut(amount, tokenReserve0, wethReserve0);
        }

        pair = IUniswapV2Pair(factory.getPair(address(weth), address(token)));
        require(
            address(pair) != address(0),
            "Neither token-weth nor weth-token pair exists");
        (uint wethReserve1, uint tokenReserve1,) = pair.getReserves();
        return UniswapV2Library.getAmountOut(amount, tokenReserve1, wethReserve1);
    }

    function rewardToken(uint256) public virtual override view returns (IERC20) {
        return IERC20(0);
    }
}
