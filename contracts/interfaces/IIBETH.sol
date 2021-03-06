// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IIBETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
    function claim(uint totalReward, bytes32[] memory proof) external;
    function claimAndWithdraw(
        uint claimAmount,
        bytes32[] memory proof,
        uint withdrawAmount
    ) external;
    function cToken() external view returns (address);
}