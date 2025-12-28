// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/UniBridgeVault.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract UniBridgeVaultTest is Test {
    UniBridgeVault public bridge;

    // Test addresses
    address public admin = address(1);
    address public relayer = address(2);
    address public user = address(3);
    address public attacker = address(4);

    // Roles identifiers (matching the contract)
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        // Deploy contract as the 'admin' address
        vm.startPrank(admin);
        bridge = new UniBridgeVault();

        // Grant the Relayer role to the 'relayer' address
        bridge.grantRole(RELAYER_ROLE, relayer);
        // Admin Revokes the Relayer role from itself
        bridge.revokeRole(RELAYER_ROLE, admin);

        vm.stopPrank();
        // Fund the bridge with some liquidity for release tests
        vm.deal(address(bridge), 100 ether);
    }

    // --- Role Access Tests ---

    function test_OnlyRelayerCanRelease() public {
        bytes32 txId = keccak256("unique_tx_1");
        // Relayer executes release successfully
        vm.prank(relayer);
        bridge.release(payable(user), 1 ether, txId);
        assertEq(user.balance, 1 ether);
    }

    // --- Replay Protection Tests ---

    function test_PreventReplayAttack() public {
        bytes32 txId = keccak256("replay_tx_id");

        // First release attempt
        vm.prank(relayer);
        bridge.release(payable(user), 1 ether, txId);

        // Second release attempt with the SAME transactionId
        vm.prank(relayer);
        vm.expectRevert("Transaction already processed");
        bridge.release(payable(user), 1 ether, txId);
    }

    function test_LockWithNonceGeneratesUniqueId() public {
        vm.deal(user, 10 ether);
        vm.startPrank(user);

        // Lock funds with nonce 1
        bridge.lock{value: 1 ether}(56, 1);

        // Try to lock again with the SAME nonce (should fail due to our logic)
        vm.expectRevert("Transfer already processed");
        bridge.lock{value: 1 ether}(56, 1);

        // Locking with a DIFFERENT nonce should work
        bridge.lock{value: 1 ether}(56, 2);
        vm.stopPrank();
    }

    // --- Emergency Controls Tests ---

    function test_EmergencyWithdrawUsingCall() public {
        uint256 amount = 5 ether;
        uint256 initialAdminBalance = admin.balance;

        // Only admin can call emergencyWithdraw
        vm.prank(admin);
        bridge.emergencyWithdraw(amount);

        assertEq(admin.balance, initialAdminBalance + amount);
        assertEq(address(bridge).balance, 95 ether);
    }

    function test_PauseMechanism() public {
        // Admin pauses the bridge
        vm.prank(admin);
        bridge.pause();

        // Users cannot lock while paused
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(); // EnforcedPause()
        bridge.lock{value: 1 ether}(56, 99);

        // Relayers cannot release while paused
        vm.prank(relayer);
        vm.expectRevert();
        bridge.release(payable(user), 1 ether, keccak256("something")); // dummy txId
    }

    function test_RevertIf_NonRelayerAttemptsRelease() public {
        bytes32 txId = keccak256("unique_tx_1");

        // Attacker tries to release funds
        vm.prank(attacker);
        // import and use AccessControlUnauthorizedAccount error from IAccessControl for revert confirmation
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                RELAYER_ROLE
            )
        );
        // Should fail because attacker lacks RELAYER_ROLE
        bridge.release(payable(attacker), 1 ether, txId);
    }

    // --- Fuzzing Test ---

    function testFuzz_ReleaseToAnyAddress(
        address recipient,
        uint256 amount
    ) public {
        // Ensure amount is within vault limits and recipient is valid
        vm.assume(recipient != address(0));
        vm.assume(amount > 0 && amount <= address(bridge).balance);
        // Avoid pre-compiled or system addresses that might behave oddly
        vm.assume(uint160(recipient) > 100);

        bytes32 txId = keccak256(abi.encode(recipient, amount));
        // Relayer role can release to any address.
        vm.prank(relayer);
        bridge.release(payable(recipient), amount, txId);

        assertEq(recipient.balance, amount);
    }
}
