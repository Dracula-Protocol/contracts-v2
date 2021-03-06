// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./libraries/UniswapV2Library.sol";
import "./IVampireAdapter.sol";

abstract contract BaseAdapter is IVampireAdapter {

    IERC20 constant _WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Factory constant PAIR_FACTORY = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    /**
     * @notice Calculates the WETH value for an amount of pool reward token
     */
    function rewardValue(uint256 poolId, uint256 amount) external virtual override view returns(uint256) {
        address token = address(rewardToken(poolId));

        IUniswapV2Pair pair = IUniswapV2Pair(PAIR_FACTORY.getPair(address(token), address(_WETH)));
        if (address(pair) != address(0)) {
                (uint tokenReserve, uint wethReserve,) = pair.getReserves();
                return UniswapV2Library.getAmountOut(amount, tokenReserve, wethReserve);
        }

        require(
            address(pair) != address(0),
            "Neither token-weth nor weth-token pair exists");
        pair = IUniswapV2Pair(PAIR_FACTORY.getPair(address(_WETH), address(token)));
        (uint wethReserve, uint tokenReserve,) = pair.getReserves();
        return UniswapV2Library.getAmountOut(amount, tokenReserve, wethReserve);
    }

    function rewardToken(uint256) public virtual override view returns (IERC20) {
        return IERC20(0);
    }
}
