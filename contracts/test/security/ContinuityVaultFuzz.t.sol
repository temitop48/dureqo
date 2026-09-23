// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "../../lib/openzeppelin-contracts/lib/forge-std/src/Test.sol";
import { ContinuityVault } from "../../src/ContinuityVault.sol";
import { SecurityMockUSDG } from "./SecurityMockUSDG.sol";

contract ContinuityVaultFuzzTest is Test {
    address private constant OWNER = address(0x1001);
    address private constant PENDING_OWNER = address(0x1002);
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

    function testFuzzAccountingViewsAfterInflows(uint128 depositAmount, uint128 directAmount)
        public
    {
        uint256 depositValue = bound(depositAmount, 1, 1e24);
        uint256 directValue = bound(directAmount, 1, 1e24);

        _deposit(OWNER, depositValue);
        token.mint(USER, directValue);
        vm.prank(USER);
        token.transfer(address(vault), directValue);

        uint256 actual = token.balanceOf(address(vault));
        assertEq(vault.availableBalance(), actual);
        assertTrue(vault.isFunded());
    }

    function testFuzzProtectedBalanceTracksOneReservationPerActiveCommitment(
        uint128 firstAmount,
        uint128 secondAmount
    ) public {
        uint256 first = bound(firstAmount, 1, 1e18);
        uint256 second = bound(secondAmount, 1, 1e18);
        _deposit(OWNER, first + second + 1);

        vm.prank(OWNER);
        uint256 oneTimeId = vault.createCommitment(USER, uint128(first), 0, uint64(block.timestamp));
        vm.prank(OWNER);
        uint256 recurringId =
            vault.createCommitment(PENDING_OWNER, uint128(second), 1, uint64(block.timestamp));
        assertEq(vault.protectedBalance(), first + second);

        vault.executeCommitment(oneTimeId);
        assertEq(vault.protectedBalance(), second);
        ContinuityVault.Commitment memory recurring = vault.getCommitment(recurringId);
        assertTrue(recurring.active);

        vm.prank(OWNER);
        vault.cancelCommitment(recurringId);
        assertEq(vault.protectedBalance(), 0);
    }

    function testFuzzActiveCautionBoundary(uint8 boundary) public {
        uint256 activeUntil = vault.activeUntil();
        uint8 point = boundary % 3;
        vm.warp(point == 0 ? activeUntil - 1 : point == 1 ? activeUntil : activeUntil + 1);
        if (point < 2) {
            assertEq(uint256(vault.mode()), uint256(ContinuityVault.Mode.ACTIVE));
        } else {
            assertEq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CAUTION));
        }
    }

    function testFuzzContinuityEligibilityBoundary(uint8 boundary) public {
        uint256 eligibleAt = vault.continuityEligibleAt();
        uint8 point = boundary % 3;
        vm.warp(point == 0 ? eligibleAt - 1 : eligibleAt);
        if (point == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(ContinuityVault.ContinuityNotEligible.selector, eligibleAt)
            );
            vault.activateContinuity();
        } else {
            vault.activateContinuity();
            assertEq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
        }
    }

    function testFuzzRecoveryDelayBoundary(uint8 boundary) public {
        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        uint256 executableAt = uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY;
        uint8 point = boundary % 3;
        uint256 timestamp = point == 0 ? executableAt - 1 : executableAt + point - 1;
        vm.warp(timestamp);

        if (point == 0) {
            vm.prank(OWNER);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ContinuityVault.RecoveryDelayNotElapsed.selector, executableAt
                )
            );
            vault.completeRecovery();
            assertTrue(vault.continuityActivated());
        } else {
            vm.prank(OWNER);
            vault.completeRecovery();
            assertFalse(vault.continuityActivated());
        }
    }

    function testFuzzExecutorCannotRedirectStoredPayment(uint256 callerSeed, uint128 amount)
        public
    {
        uint256 payment = bound(amount, 1, 1e18);
        address caller = callerSeed % 2 == 0 ? USER : PENDING_OWNER;
        _deposit(OWNER, payment);
        vm.prank(OWNER);
        uint256 id = vault.createCommitment(USER, uint128(payment), 0, uint64(block.timestamp));

        vm.prank(caller);
        vault.executeCommitment(id);
        assertEq(token.balanceOf(USER), payment);
        assertEq(token.balanceOf(caller), caller == USER ? payment : 0);
        assertFalse(vault.getCommitment(id).active);
    }

    function testFuzzFailedDepositDoesNotCreatePhantomBalance(uint128 amount) public {
        uint256 value = bound(amount, 1, 1e24);
        token.mint(OWNER, value);
        vm.prank(OWNER);
        token.approve(address(vault), value);
        token.setFailTransferFrom(true);

        vm.prank(OWNER);
        vm.expectRevert();
        vault.deposit(value);
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(vault.protectedBalance(), 0);
    }

    function testFuzzFailedWithdrawalDoesNotMutateFinancialState(uint128 amount) public {
        uint256 value = bound(amount, 1, 1e24);
        _deposit(OWNER, value);
        token.setFailTransfer(true);
        vm.prank(OWNER);
        vm.expectRevert();
        vault.withdrawAvailable(USER, value);
        assertEq(token.balanceOf(address(vault)), value);
        assertEq(vault.availableBalance(), value);
    }

    function testFuzzFailedExecutionsRollBackCommitmentState(uint128 amount, bool recurring)
        public
    {
        uint256 payment = bound(amount, 1, 1e18);
        _deposit(OWNER, payment);
        vm.prank(OWNER);
        uint256 id = vault.createCommitment(
            USER, uint128(payment), recurring ? uint64(1) : uint64(0), uint64(block.timestamp)
        );
        ContinuityVault.Commitment memory beforeExecution = vault.getCommitment(id);
        token.setFailTransfer(true);

        vm.expectRevert();
        vault.executeCommitment(id);
        ContinuityVault.Commitment memory afterExecution = vault.getCommitment(id);
        assertEq(afterExecution.nextDue, beforeExecution.nextDue);
        assertEq(afterExecution.active, beforeExecution.active);
        assertEq(vault.protectedBalance(), payment);
    }

    function testFuzzUnderfundedVaultCannotWithdrawButCanRecover(uint128 amount) public {
        uint256 payment = bound(amount, 2, 1e18);
        _deposit(OWNER, payment * 2);
        vm.prank(OWNER);
        uint256 id = vault.createCommitment(USER, uint128(payment), 1, uint64(block.timestamp));
        vault.executeCommitment(id);
        vm.warp(block.timestamp + 1);
        vault.executeCommitment(id);
        assertFalse(vault.isFunded());
        assertEq(vault.availableBalance(), 0);

        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(ContinuityVault.InsufficientAvailableBalance.selector, 1, 0)
        );
        vault.withdrawAvailable(OWNER, 1);

        _activateContinuity();
        vm.prank(OWNER);
        vault.requestRecovery();
        vm.warp(uint256(vault.recoveryRequestedAt()) + RECOVERY_DELAY);
        vm.prank(OWNER);
        vault.completeRecovery();
        assertFalse(vault.isFunded());
    }

    function testTokenCallbackCannotReenterDeposit(uint128 amount) public {
        uint256 value = bound(amount, 1, 1e18);
        token.mint(OWNER, value + 1);
        vm.prank(OWNER);
        token.approve(address(vault), value + 1);
        token.setCallback(address(vault), abi.encodeWithSelector(vault.deposit.selector, 1));

        vm.prank(OWNER);
        vault.deposit(value);
        assertTrue(token.callbackAttempted());
        assertFalse(token.callbackSucceeded());
        assertEq(token.balanceOf(address(vault)), value);
    }

    function testTokenCallbackCannotReenterExecution() public {
        _deposit(OWNER, 10 ether);
        vm.prank(OWNER);
        uint256 id = vault.createCommitment(USER, 10 ether, 0, uint64(block.timestamp));
        token.setCallback(
            address(vault), abi.encodeWithSelector(vault.executeCommitment.selector, id)
        );

        vault.executeCommitment(id);
        assertTrue(token.callbackAttempted());
        assertFalse(token.callbackSucceeded());
        assertFalse(vault.getCommitment(id).active);
        assertEq(token.balanceOf(USER), 10 ether);
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
