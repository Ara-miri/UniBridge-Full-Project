// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UniBridgeVault is ReentrancyGuard, Ownable {
    // رویداد برای مانیتورینگ توسط بک‌اِند (Bridge API)
    event Lock(address indexed user, uint256 amount, uint256 targetChainId);
    event Release(address indexed user, uint256 amount);

    mapping(address => uint256) public lockedBalances;

    constructor() Ownable(msg.sender) {}

    // قفل کردن دارایی در شبکه مبدا (مثلاً Ethereum)
    function lock(uint256 _amount) external payable nonReentrant {
        require(msg.value == _amount, "Must send exact amount");
        lockedBalances[msg.sender] += _amount;
        
        // این ایندکسرها (Graph) این رویداد را می‌خوانند
        emit Lock(msg.sender, _amount, 56); // 56 کد شبکه BSC است
    }

    // آزاد کردن دارایی در شبکه مقصد (توسط ریلایر/ادمین تایید شده)
    function release(address _user, uint256 _amount) external onlyOwner {
        (bool success, ) = _user.call{value: _amount}("");
        require(success, "Transfer failed");
        
        emit Release(_user, _amount);
    }
}