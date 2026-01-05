# UniBridge Vault 🚀

A high-performance, professional-grade smart contract designed for **secure cross-chain native asset bridging**. Built with **Solidity 0.8.20** and strictly follows industry security standards, including Role-Based Access Control (RBAC) and Replay Protection.

---

## 📌 Overview

**UniBridge Vault** facilitates the transfer of native assets (ETH, BNB, TRX) between different blockchain networks. It uses a **Lock-and-Release** mechanism:

:one: **Source Chain:** User calls `lock()`, depositing native currency into the vault.

:two: **Off-Chain:** A relayer detects the `Locked` event.

:three: **Target Chain:** The relayer calls `release()` to deliver the equivalent funds to the user.

---

## ✨ Key Features

- **Role-Based Access Control (RBAC):** Utilizes OpenZeppelin's `AccessControlEnumerable` to separate administrative duties from operational relayer tasks.
- **Replay Protection:** Implements unique `transactionId` hashing (incorporating `chainid`, `nonce`, and `sender`) to prevent double-spending and cross-network replay attacks.
- **Pausable Security:** Includes an emergency circuit breaker to halt all bridge operations in case of a detected vulnerability.
- **Gas Optimized:** Uses **Custom Errors** instead of string-based `require` statements to reduce gas costs during reverts.
- **Safe Transfers:** Uses low-level `.call` for native transfers to support Multisig wallets (Gnosis Safe) and other smart contract recipients.

---

## 🛠 Tech Stack

- **Language:** Solidity 0.8.20
- **Framework:** [Foundry](https://book.getfoundry.sh/)
- **Libraries:** [OpenZeppelin](https://openzeppelin.com/contracts/)
- `AccessControlEnumerable`: Role management with on-chain member tracking.
- `ReentrancyGuard`: Prevention of recursive call attacks.
- `Pausable`: Emergency operational control.

---

## 📖 Smart Contract API

### Core Functions

| Function                             | Access      | Description                                                     |
| ------------------------------------ | ----------- | --------------------------------------------------------------- |
| `lock(uint256, uint256)`             | Public      | Deposits native assets and emits a `Locked` event for bridging. |
| `release(address, uint256, bytes32)` | **Relayer** | Releases native assets on the target chain to a recipient.      |
| `emergencyWithdraw(uint256)`         | **Admin**   | Allows the admin to recover funds in extreme scenarios.         |
| `pause()` / `unpause()`              | **Admin**   | Controls the circuit breaker for bridge operations.             |

### View Functions

- **`getAllRelayers()`**: Returns a list of all addresses authorized to execute releases.
- **`getAllAdmins()`**: Returns a list of all administrative addresses.
- **`processedNonces(bytes32)`**: Checks if a specific transaction ID has already been executed.

---

## 🚀 Getting Started

### Prerequisites

- [Foundry installed](https://getfoundry.sh/)
- OpenZeppelin Contracts `forge install OpenZeppelin/openzeppelin-contracts`

### Installation

```bash
# Clone the repository
git clone https://github.com/Ara-miri/UniBridge-Full-Project.git
cd unibridge-vault

# Build the project
forge build

```

### Running Tests

This project includes a comprehensive test suite covering RBAC, security reverts, and fuzz testing.

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Check coverage
forge coverage --report lcov

```

---

## 🔒 Security Design

### Transaction Identity

The `transactionId` is generated using:
$$transactionId = \text{keccak256}(\text{sender}, \text{targetChainId}, \text{nonce}, \text{sourceChainId})$$
This ensures that a transaction signed for one chain cannot be "replayed" on another, nor can a user repeat a transaction using the same nonce.

### Custom Errors

The contract defines specific errors for better debugging and gas efficiency:

- `UniBridgeVault_AmountMustBeGreaterThanZero()`
- `UniBridgeVault_TransactionAlreadyProcessed()`
- `UniBridgeVault_InsufficientBridgeLiquidity()`
- `UniBridgeVault_InsufficientBridgeLiquidityForEmergencyWithdraw()`

---

## 📄 License

This project is licensed under the **MIT License** [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT).
