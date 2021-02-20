// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

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
    IRariFundManager constant FUND_MANAGER = IRariFundManager(0xD6e194aF3d9674b62D1b30Ec676030C23961275e);
    IUniswapV2Pair immutable DRC_WETH_PAIR;
    IERC20 immutable dracula;

    constructor(address _dracula) public {
        dracula = IERC20(_dracula);
        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        DRC_WETH_PAIR = IUniswapV2Pair(uniswapFactory.getPair(address(WETH), _dracula));
    }

    function handleDrainedWETH(uint256 amount) external override {
        WETH.withdraw(amount);
        FUND_MANAGER.deposit{value: amount}();
    }

    function handleClaim(uint256 pending, uint8 flag) external override {
        FUND_MANAGER.withdraw(pending);

        if ((flag & 0x2) == 0) {
            _safeETHTransfer(msg.sender, pending);
        } else {
            WETH.deposit{value: pending}();
            address token0 = DRC_WETH_PAIR.token0();
            (uint reserve0, uint reserve1,) = DRC_WETH_PAIR.getReserves();
            (uint reserveInput, uint reserveOutput) = address(WETH) == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            uint amountOutput = UniswapV2Library.getAmountOut(pending, reserveInput, reserveOutput);
            (uint amount0Out, uint amount1Out) = address(WETH) == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));

            WETH.transfer(address(DRC_WETH_PAIR), pending);
            DRC_WETH_PAIR.swap(amount0Out, amount1Out, address(this), new bytes(0));
            dracula.transfer(msg.sender, amountOutput);
        }
    }

    function migrate() external override {
    }
}
