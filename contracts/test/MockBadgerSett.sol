// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockBadgerSett is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    IERC20 immutable public token;

    constructor (
        string memory name,
        string memory symbol,
        address _token
    ) ERC20(name, symbol) {
        token = IERC20(_token);
    }

    function getPricePerFullShare() public view virtual returns (uint256) {
        if (totalSupply() == 0) {
            return 1e18;
        }
        return balance().mul(1e18).div(totalSupply());
    }

    function balance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function deposit(uint256 _amount) public {
        _deposit(_amount);
    }

    function depositAll() external {
        _deposit(token.balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public {
        _withdraw(_shares);
    }

    function withdrawAll() external {
        _withdraw(balanceOf(msg.sender));
    }

    function _deposit(uint256 _amount) internal {
        uint256 _pool = balance();
        uint256 _before = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = token.balanceOf(address(this));
        _amount = _after.sub(_before); // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
    }

    function _withdraw(uint256 _shares) internal {
        uint256 r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);
        token.safeTransfer(msg.sender, r);
    }
}
