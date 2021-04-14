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

    function _deposit(uint256 _amount) internal {
        uint256 _pool = balance();
        uint256 shares = 0;
        if (reptToken.totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(reptToken.totalSupply())).div(_pool);
        }
        balances[msg.sender] = balances[msg.sender].add(_amount);
        reptToken.mint(msg.sender, shares);
    }

    function _withdraw(uint256 _amount) internal {
        uint256 r = (balance().mul(_amount)).div(reptToken.totalSupply());
        reptToken.burnFrom(msg.sender, _amount);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        msg.sender.transfer(r);
    }
}
