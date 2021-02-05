// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/Exponential.sol";
import "./interfaces/CarefulMath.sol";
import "./interfaces/IIBETH.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/CToken.sol";
import "./IMasterVampire.sol";

/**
* @title Handles interest bearing ETH for the Vamps in MasterVampire
*/
contract IBVEth is IMasterVampire, Exponential {
    IIBETH constant IBETH = IIBETH(0xeEa3311250FE4c3268F8E684f7C87A82fF183Ec1);

    function handleDrainedWETH(uint256 amount) external {
        WETH.withdraw(amount);
        IBETH.deposit{value: amount}();
    }

    function handleClaim(uint256 pending) external {
        ICToken cToken = ICToken(IBETH.cToken());
        (, uint256 redeemAmount) = divScalarByExpTruncate(pending, Exp({mantissa: cToken.exchangeRateStored()}));
        IBETH.withdraw(redeemAmount);
        _safeETHTransfer(msg.sender, pending);
    }

    function _safeETHTransfer(address payable to, uint256 amount) internal {
        uint256 balance = address(this).balance;
        if (amount > balance) {
            to.transfer(balance);
        } else {
            to.transfer(amount);
        }
    }
}
