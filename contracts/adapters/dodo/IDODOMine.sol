// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDODOMine{
    function poolInfos(uint256) external view returns (address,uint256,uint256,uint256);
    function userInfo(uint256, address) external view returns (uint256,uint256);
    function poolLength() external view returns (uint256);
    function deposit(address _lpToken, uint256 _amount) external;
    function withdraw(address _lpToken, uint256 _amount) external;
    function emergencyWithdraw(address _lpToken) external;
    function claim(address _lpToken) external;
    function getPendingReward(address _lpToken, address _user) external view returns (uint256);
}
