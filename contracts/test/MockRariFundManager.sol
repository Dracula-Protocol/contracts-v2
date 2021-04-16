// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IRariFundManager.sol";
import "./MockERC20.sol";

contract MockRariFundManager is IRariFundManager {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    MockERC20 public immutable reptToken;
    mapping(address => uint256) public balances;

    constructor () {
        reptToken = new MockERC20("RARI ETH", "REPT", 18);
    }

    receive() external payable {
        _deposit(msg.value);
    }

    function rariFundToken() external view override returns (IERC20) {
        return IERC20(address(reptToken));
    }

    function getFundBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function deposit() external override payable {
        _deposit(msg.value);
    }

    function withdraw(uint256 _amount) external override returns (bool) {
        _withdraw(_amount);
        return true;
    }

    function _deposit(uint256 _ethAmount) internal {
        uint256 totalETH = balance();
        uint256 totalShares = reptToken.totalSupply();
        uint256 shares = 0;
        if (totalShares == 0 || totalETH == 0) {
            shares = _ethAmount;
        } else {
            // Note: input amount of eth is subtracted from total ETH because by the time
            // we hit this statement, totalETH already includes ethAmount and would skew the
            // calculation of shares.
            shares = _ethAmount.mul(totalShares).div(totalETH.sub(_ethAmount));
        }

        balances[msg.sender] = balances[msg.sender].add(_ethAmount);
        reptToken.mint(msg.sender, shares);
    }

    function _withdraw(uint256 _ethAmount) internal {
        uint256 totalETH = balance();
        uint256 totalShares = reptToken.totalSupply();
        uint256 reptAmount = _ethAmount.mul(totalShares).div(totalETH);
        reptToken.burnFrom(msg.sender, reptAmount);
        balances[msg.sender] = balances[msg.sender].sub(_ethAmount);
        msg.sender.transfer(_ethAmount);
    }
}
