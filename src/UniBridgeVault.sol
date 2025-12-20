// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UniBridgeVault
 * @dev A cross-chain vault for locking assets on one chain and releasing them on another.
 * Covers: Security, Gas Optimization, and Multi-chain logic.
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract UniBridgeVault is ReentrancyGuard, Ownable, Pausable {
    // Mapping to track user balances locked in the contract
    mapping(address => uint256) public lockedBalances;

    // Events for off-chain indexers (Backend/APIs) to monitor
    event Locked(address indexed user, uint256 amount, uint256 targetChainId);
    event Released(address indexed user, uint256 amount);

    error UniBridgeVault__ValueMustGreaterThanZero();
    error UniBridgeVault__ZeroAddress();
    error UniBridgeVault__InsufficientVaultLiquidity();

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Locks ETH/Native token into the vault to be bridged to another chain.
     * @param _targetChainId The destination chain ID (e.g., 56 for BSC).
     */
    function lock(
        uint256 _targetChainId
    ) external payable nonReentrant whenNotPaused {
        if (msg.value <= 0) revert UniBridgeVault__ValueMustGreaterThanZero();

        // Gas Optimization: Using unchecked for incrementing balance
        // as msg.value + existing balance is unlikely to overflow in EVM 0.8+
        unchecked {
            lockedBalances[msg.sender] += msg.value;
        }

        emit Locked(msg.sender, msg.value, _targetChainId);
    }

    /**
     * @notice Releases funds to a user. Called by the Bridge Relayer (Admin).
     * @dev Implements Checks-Effects-Interactions pattern for security.
     * @param _user The recipient address.
     * @param _amount The amount to release.
     */
    function release(
        address payable _user,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        if (_user == address(0)) revert UniBridgeVault__ZeroAddress();
        if (address(this).balance <= _amount)
            revert UniBridgeVault__InsufficientVaultLiquidity();

        // Interaction: Send the funds
        (bool success, ) = _user.call{value: _amount}("");
        require(success, "Transfer failed");

        emit Released(_user, _amount);
    }

    /**
     * @notice Emergency stop mechanism.
     * Requirement of the "Security Optimization" job point.
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Function to check contract's total liquidity
    function getVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
