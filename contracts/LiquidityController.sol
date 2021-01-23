// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/UniswapV2Library.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./DraculaToken.sol";

/**
* @title Adds liquidity to DRC/ETH pool
*/
contract LiquidityController is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for DraculaToken;

    DraculaToken constant DRACULA = DraculaToken(0xb78B3320493a4EFaa1028130C5Ba26f0B6085Ef8);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant DRC_WETH_PAIR = IUniswapV2Pair(0x276E62C70e0B540262491199Bc1206087f523AF6);
    IUniswapV2Router02 constant UNI_ROUTER = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public lpDestination = 0xa896e4bd97a733F049b23d2AcEB091BcE01f298d;

    /// @notice Construct and approve spending for LP assets
    constructor() public {
        DRACULA.approve(address(UNI_ROUTER), uint256(-1));
        WETH.approve(address(UNI_ROUTER), uint256(-1));
    }

    /**
     * @notice Transfers specified amount of WETH from caller and uses half to buy DRC.
     *         The DRC and remaining WETH are added to liquidity pool.
     *         LP token is sent to a treasury.
     * @param amount the amount of WETH to transfer from caller
     */
    function addLiquidity(uint256 amount) external {
        require(amount > 0, "amount == 0");
        WETH.safeTransferFrom(msg.sender, address(this), amount);
        uint256 halfWethBalance = WETH.balanceOf(address(this)).div(2);
        WETH.safeTransfer(address(DRC_WETH_PAIR), halfWethBalance);
        (uint drcReserve, uint wethReserve,) = DRC_WETH_PAIR.getReserves();
        uint256 amountOutput = UniswapV2Library.getAmountOut(halfWethBalance, wethReserve, drcReserve);
        DRC_WETH_PAIR.swap(amountOutput, uint256(0), address(this), new bytes(0));

        UNI_ROUTER.addLiquidity(address(DRACULA),
                                address(WETH),
                                amountOutput,
                                halfWethBalance,
                                1,
                                1,
                                lpDestination,
                                block.timestamp + 2 hours);
        DRACULA.burn(DRACULA.balanceOf(address(this)));
    }

    /**
     * @notice Changes the address where LP token is sent
     * @param lpDestination_ the new address
     */
    function changeLPDestination(address lpDestination_) external onlyOwner {
        require(lpDestination_ != address(0), "invalid destination");
        lpDestination = lpDestination_;
    }

    /**
     * @notice Provides a way to withdraw any remaining WETH and DRC
     * @param to Address to send
     */
    function collectDust(address to) external onlyOwner {
        WETH.safeTransfer(to, WETH.balanceOf(address(this)));
        DRACULA.safeTransfer(to, DRACULA.balanceOf(address(this)));
    }
}
