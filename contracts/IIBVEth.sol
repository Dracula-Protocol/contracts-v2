// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWETH.sol";

/**
* @title Interface for interest bearing ETH strategies
*/
abstract contract IIBVEth  {

    IWETH immutable WETH;

    constructor(address weth) {
        WETH = IWETH(weth);
    }

    function handleDrainedWETH(uint256 amount) external virtual;
    function handleClaim(uint256 pending, uint8 flag) external virtual;
    function migrate() external virtual;
    function ibToken() external view virtual returns(IERC20);
    function balance(address account) external view virtual returns(uint256);
    function ethBalance(address account) external virtual returns(uint256);
    function ibETHValue(uint256 amount) external virtual returns (uint256);

    function _safeETHTransfer(address payable to, uint256 amount) internal virtual {
        uint256 _balance = address(this).balance;
        if (amount > _balance) {
            to.transfer(_balance);
        } else {
            to.transfer(amount);
        }
    }
}
