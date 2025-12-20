// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UniBridgeVault.sol";

contract UniBridgeVaultTest is Test {
    UniBridgeVault public vault;
    address public owner = address(1);
    address public user = address(2);
    address public recipient = address(3);

    // Setup function runs before every test
    function setUp() public {
        vm.prank(owner); // The next call will be issued by 'owner'
        vault = new UniBridgeVault();
    }

    // --- Core Logic Tests ---

    function test_LockFunds() public {
        vm.deal(user, 10 ether); // Give the user some fake ETH

        vm.startPrank(user);
        uint256 targetChainId = 56; // BSC

        // Expect the Locked event to be emitted
        vm.expectEmit(true, false, false, true);
        emit UniBridgeVault.Locked(user, 1 ether, targetChainId);

        vault.lock{value: 1 ether}(targetChainId);
        vm.stopPrank();

        assertEq(vault.getVaultBalance(), 1 ether);
        assertEq(vault.lockedBalances(user), 1 ether);
    }

    function test_RevertIf_LockValueIsZero() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        uint256 targetChainId = 56; // BSC

        // passing 0 as msg.value should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("UniBridgeVault__ValueMustGreaterThanZero()"))
            )
            // OR
            /*
            abi.encodeWithSignature(
                "UniBridgeVault__ValueMustGreaterThanZero()")
            */
        );
        vault.lock{value: 0}(targetChainId);
        vm.stopPrank();
    }

    function test_RevertIf_NonOwnerReleases() public {
        vm.deal(address(vault), 5 ether);
        vm.prank(user);

        // Standard Ownable error for unauthorized access
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                user
            )
        );
        vault.release(payable(user), 1 ether);
    }

    function test_RevertIf_ZeroAddressPassedToRelease() public {
        vm.deal(address(vault), 5 ether);

        //only owner can call release function
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("UniBridgeVault__ZeroAddress()"))
            )
        );
        vault.release(payable(0), 1 ether);
    }

    function test_RevertIf_VaultBalanceIsLowerThanAmount() public {
        vm.deal(address(vault), 5 ether);

        //only owner can call release function
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(
                    keccak256("UniBridgeVault__InsufficientVaultLiquidity()")
                )
            )
        );
        vault.release(payable(user), 10 ether);
    }

    function test_RevertIf_Paused() public {
        vm.prank(owner);
        vault.pause();

        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vault.lock{value: 1 ether}(56);
    }

    function test_IfNotPaused() public {
        vm.startPrank(owner);
        vault.pause();
        vault.unpause();
        vm.stopPrank();

        vm.deal(user, 1 ether);
        vm.prank(user);
        vault.lock{value: 1 ether}(56);
        assertEq(vault.getVaultBalance(), 1 ether);
    }

    // --- Fuzz Testing ---
    // This will run 256 times with random values to find edge cases
    function testFuzz_Lock(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e18); // Stay within realistic bounds
        vm.deal(user, amount);

        vm.prank(user);
        vault.lock{value: amount}(56);

        assertEq(vault.getVaultBalance(), amount);
    }

    // --- Testing Withdrawals ---
    function test_ReleaseFunds() public {
        vm.deal(address(vault), 10 ether);
        uint256 initialBalance = recipient.balance;
        console.log(initialBalance);
        vm.prank(owner);
        vault.release(payable(recipient), 2 ether);

        assertEq(recipient.balance, initialBalance + 2 ether);
        assertEq(vault.getVaultBalance(), 8 ether);
    }
}
