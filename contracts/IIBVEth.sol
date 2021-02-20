// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/**
* @title Interface for interest bearing ETH strategies
*/
abstract contract IIBVEth  {
    function handleDrainedWETH(uint256 amount) external virtual;
    function handleClaim(uint256 pending, uint8 flag) external virtual;
    function migrate() external virtual;

    function _safeETHTransfer(address payable to, uint256 amount) internal virtual {
        uint256 balance = address(this).balance;
        if (amount > balance) {
            to.transfer(balance);
        } else {
            to.transfer(amount);
        }
    }
}
