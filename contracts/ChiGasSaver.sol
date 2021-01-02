// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IFreeFromUpTo {
    function freeFromUpTo(address from, uint256 value) external returns(uint256 freed);
}

/**
* @title Inheritable contract to enable optional gas savings on functions via a modifier
*/
abstract contract ChiGasSaver {

    modifier saveGas(uint8 flag) {
        if ((flag & 0x1) == 0) {
            _;
        } else {
            uint256 gasStart = gasleft();
            _;
            uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;

            IFreeFromUpTo chi = IFreeFromUpTo(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);
            chi.freeFromUpTo(msg.sender, (gasSpent + 14154) / 41947);
        }
    }
}