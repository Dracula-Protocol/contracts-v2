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
    IUniswapV2Router02 constant YFL_ROUTER = IUniswapV2Router02(0xA7eCe0911FE8C60bff9e99f8fAFcDBE56e07afF1);
    address public lpDestination = 0xa896e4bd97a733F049b23d2AcEB091BcE01f298d;
    uint256 public wethThreshold = 200000000000000000 wei;
    uint256 public burnShare = 50; // Percentage using decimal base of 1000 ie: 10% = 100

    /// @notice Construct and approve spending for LP assets
    constructor() public {
        DRACULA.approve(address(UNI_ROUTER), type(uint256).max);
        WETH.approve(address(UNI_ROUTER), type(uint256).max);
        DRACULA.approve(address(YFL_ROUTER), type(uint256).max);
        WETH.approve(address(YFL_ROUTER), type(uint256).max);
    }

    /**
     * @notice Transfers specified amount of WETH from caller and uses half to buy DRC.
     *         The DRC and remaining WETH are added to liquidity pools.
     *         LP token is sent to a treasury.
     * @param amount the amount of WETH to transfer from caller
     */
    function addLiquidity(uint256 amount) external {
        require(amount > 0, "amount == 0");
        WETH.safeTransferFrom(msg.sender, address(this), amount);
        uint256 wethBalance = WETH.balanceOf(address(this));
        if (wethBalance < wethThreshold) {
            return;
        }

        uint256 halfWethBalance = wethBalance.div(2);
        WETH.safeTransfer(address(DRC_WETH_PAIR), halfWethBalance);
        (uint drcReserve, uint wethReserve,) = DRC_WETH_PAIR.getReserves();
        uint256 drcAmountOutput = UniswapV2Library.getAmountOut(halfWethBalance, wethReserve, drcReserve);
        DRC_WETH_PAIR.swap(drcAmountOutput, uint256(0), address(this), new bytes(0));

        drcAmountOutput = drcAmountOutput.div(2);
        drcAmountOutput = drcAmountOutput.sub(drcAmountOutput.mul(burnShare).div(1000));
        halfWethBalance = halfWethBalance.div(2);
        halfWethBalance = halfWethBalance.sub(halfWethBalance.mul(burnShare).div(1000));

        UNI_ROUTER.addLiquidity(address(DRACULA),
                                address(WETH),
                                drcAmountOutput,
                                halfWethBalance,
                                1,
                                1,
                                lpDestination,
                                block.timestamp + 2 hours);

        YFL_ROUTER.addLiquidity(address(DRACULA),
                                address(WETH),
                                drcAmountOutput,
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
     * @notice Change the WETH threshold
     */
    function setWETHThreshold(uint256 wethThreshold_) external onlyOwner {
        wethThreshold = wethThreshold_;
    }

    /**
     * @notice Change the burn percent
     */
    function setBurnShare(uint256 burnShare_) external onlyOwner {
        require(burnShare_ <= 500, "invalid burn rate");
        burnShare = burnShare_;
    }

    /**
     * @notice Provides a way to withdraw any remaining WETH and DRC
     * @param to Address to send
     */
    function collectDust(address to) public onlyOwner {
        WETH.safeTransfer(to, WETH.balanceOf(address(this)));
        DRACULA.safeTransfer(to, DRACULA.balanceOf(address(this)));
    }

    /**
     * @notice Destruct contract to get a refund and also move any left over tokens to specified address
     * @param to Address to send any remaining tokens to before contract is destroyed
     */
    function kill(address to) external onlyOwner {
        collectDust(to);
        selfdestruct(msg.sender);
    }
}
