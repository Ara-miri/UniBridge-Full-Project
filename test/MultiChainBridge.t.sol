// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../src/UniBridgeVault.sol";

contract MultiChainTest is Test {
    UniBridgeVault sepoliaEthVault;
    UniBridgeVault opSepoliaVault;

    uint256 sepoliaFork;
    uint256 opSepoliaFork;

    address user = address(0x123);
    address owner = address(1);

    function setUp() public {
        string memory sepoliaApiKey = vm.envString("SEPOLIA_RPC_URL");
        string memory opSepoliaApiKey = vm.envString("OP_SEPOLIA_RPC_URL");
        // 1. Create forks using RPC URLs
        sepoliaFork = vm.createFork(sepoliaApiKey);
        opSepoliaFork = vm.createFork(opSepoliaApiKey);

        // 2. Deploy contract on Ethereum Sepolia fork
        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        sepoliaEthVault = new UniBridgeVault();

        // 3. Deploy contract on OP Sepolia fork
        vm.selectFork(opSepoliaFork);
        opSepoliaVault = new UniBridgeVault();
        vm.stopPrank();
    }

    function test_BridgeSimulation() public {
        // --- STEP 1: LOCK ON SEPOLIA ---
        vm.selectFork(sepoliaFork);
        vm.deal(user, 1 ether);
        vm.prank(user);
        /**
         * @notice 1 is OP Sepolia chain id (Destination chain id) and 0 is Sepolia chain id
         * unreal chain ids for testing purposes only
         */
        sepoliaEthVault.lock{value: 1 ether}(1);
        assertEq(address(sepoliaEthVault).balance, 1 ether);

        // --- STEP 2: RELEASE ON OP Sepolia ---
        // (Simulating what the Relayer would do)
        vm.selectFork(opSepoliaFork);
        /**
         * @notice Ensure OP Sepolia vault has liquidity.
         * Also it should have a little more to cover fees
         */
        vm.deal(address(opSepoliaVault), 1.1 ether);

        uint256 initialBalance = user.balance;
        vm.prank(owner);
        // Owner calls release on the SECOND chain
        opSepoliaVault.release(payable(user), 1 ether);

        assertEq(user.balance, initialBalance + 1 ether);
    }
}
