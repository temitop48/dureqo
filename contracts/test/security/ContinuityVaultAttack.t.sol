// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "../../lib/openzeppelin-contracts/lib/forge-std/src/Test.sol";
import { ContinuityVault } from "../../src/ContinuityVault.sol";
import { SecurityMockUSDG } from "./SecurityMockUSDG.sol";

contract ContinuityVaultAttackTest is Test {
    address private constant OWNER = address(0x1001);
    address private constant SUCCESSOR = address(0x1002);
    address private constant USER = address(0x1003);
    uint64 private constant HEARTBEAT = 1 days;
    uint64 private constant GRACE = 2 days;
    uint64 private constant RECOVERY_DELAY = 3 days;

    SecurityMockUSDG private token;
    ContinuityVault private vault;

    function setUp() public {
        token = new SecurityMockUSDG();
        vault = new ContinuityVault(OWNER, address(token), HEARTBEAT, GRACE, RECOVERY_DELAY);
    }

    function testAdversarialLifecyclePreservesReservationsAcrossModes() public {
        _deposit(OWNER, 150 ether);
        vm.prank(OWNER);
        uint256 oneTimeId = vault.createCommitment(USER, 20 ether, 0, uint64(block.timestamp));
        vm.prank(OWNER);
        uint256 recurringId = vault.createCommitment(USER, 10 ether, 1, uint64(block.timestamp));

        token.mint(USER, 50 ether);
        vm.prank(USER);
        token.transfer(address(vault), 50 ether);
        vm.prank(OWNER);
        vault.withdrawAvailable(OWNER, 100 ether);
        assertEq(token.balanceOf(address(vault)), 100 ether);
        assertEq(vault.protectedBalance(), 30 ether);

        vm.warp(vault.activeUntil() + 1);
        vault.executeCommitment(oneTimeId);
        assertEq(vault.protectedBalance(), 10 ether);
        assertEq(token.balanceOf(USER), 20 ether);

        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
        vault.executeCommitment(recurringId);
        assertEq(vault.protectedBalance(), 10 ether);
        assertEq(token.balanceOf(USER), 30 ether);

        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();

        uint256 available = vault.availableBalance();
        vm.prank(OWNER);
        vault.withdrawAvailable(OWNER, available);
        assertEq(token.balanceOf(address(vault)), vault.protectedBalance());
    }

    function testSuccessorAcceptanceDuringRecoveryDefeatsOldOwnerControl() public {
        vm.prank(OWNER);
        vault.transferOwnership(SUCCESSOR);
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        uint256 requestedAt = vault.recoveryRequestedAt();

        vm.prank(SUCCESSOR);
        vault.acceptOwnership();
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), OWNER)
        );
        vault.completeRecovery();

        vm.warp(requestedAt + RECOVERY_DELAY);
        vm.prank(SUCCESSOR);
        vault.completeRecovery();
        assertEq(vault.owner(), SUCCESSOR);
        assertEq(vault.recoveryRequestedAt(), 0);
    }

    function testRecurringLongDelayHasNoCatchUpOrSameOccurrenceDoublePayment() public {
        _deposit(OWNER, 100 ether);
        vm.prank(OWNER);
        uint256 id = vault.createCommitment(USER, 30 ether, 1, uint64(block.timestamp));

        vault.executeCommitment(id);
        uint256 firstPayment = token.balanceOf(USER);
        vm.warp(block.timestamp + 365 days);
        vault.executeCommitment(id);
        assertEq(token.balanceOf(USER), firstPayment + 30 ether);
        uint64 nextDue = vault.getCommitment(id).nextDue;

        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.CommitmentNotDue.selector, id, nextDue)
        );
        vault.executeCommitment(id);
        assertEq(token.balanceOf(USER), firstPayment + 30 ether);
    }

    function testUnderfundedContinuityExecutesOnlyFundedCommitmentAndStillRecovers() public {
        _deposit(OWNER, 50 ether);
        vm.prank(OWNER);
        uint256 firstId = vault.createCommitment(USER, 20 ether, 1, uint64(block.timestamp));
        vm.prank(OWNER);
        uint256 secondId = vault.createCommitment(SUCCESSOR, 30 ether, 1, uint64(block.timestamp));

        vault.executeCommitment(firstId);
        vm.warp(block.timestamp + 1);
        vault.executeCommitment(firstId);
        assertFalse(vault.isFunded());

        _activateContinuity();
        vm.expectRevert(
            abi.encodeWithSelector(
                ContinuityVault.InsufficientVaultBalance.selector, 30 ether, 10 ether
            )
        );
        vault.executeCommitment(secondId);

        _deposit(USER, 20 ether);
        _deposit(USER, 10 ether);
        vault.executeCommitment(secondId);
        assertEq(token.balanceOf(SUCCESSOR), 30 ether);

        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();
        assertEq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
    }

    function _deposit(address actor, uint256 amount) private {
        token.mint(actor, amount);
        vm.prank(actor);
        token.approve(address(vault), amount);
        vm.prank(actor);
        vault.deposit(amount);
    }

    function _activateContinuity() private {
        vm.warp(vault.continuityEligibleAt());
        vault.activateContinuity();
    }
}
