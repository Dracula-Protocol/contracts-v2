// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract IRewardSupplier is Ownable {
    mapping(address => bool) public suppliers;

    constructor(address supplier) {
        suppliers[supplier] = true;
    }

    function fundPool(uint256 reward) external virtual;

    modifier onlyRewardSupplier() {
        require(suppliers[_msgSender()] == true, "Caller is not reward supplier");
        _;
    }

    function addRewardSupplier(address supplier)
        external
        onlyOwner
    {
        suppliers[supplier] = true;
    }

    function removeRewardSupplier(address supplier)
        external
        onlyOwner
    {
        suppliers[supplier] = false;
    }
}
