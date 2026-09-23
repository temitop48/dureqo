// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "../../lib/openzeppelin-contracts/lib/forge-std/src/Test.sol";
import { ContinuityVault } from "../../src/ContinuityVault.sol";
import { ContinuityVaultHandler } from "./handlers/ContinuityVaultHandler.sol";

contract ContinuityVaultInvariantTest is Test {
    ContinuityVaultHandler private handler;
    ContinuityVault private vault;

    function setUp() public {
        handler = new ContinuityVaultHandler();
        vault = handler.vault();
        targetContract(address(handler));
    }

    function invariant_actualBalanceViewsAreConsistent() public view {
        uint256 actual = handler.token().balanceOf(address(vault));
        uint256 protectedAmount = vault.protectedBalance();
        uint256 expectedAvailable = actual > protectedAmount ? actual - protectedAmount : 0;
        assertEq(vault.availableBalance(), expectedAvailable);
        assertEq(vault.isFunded(), actual >= protectedAmount);
    }

    function invariant_protectedBalanceEqualsActiveCommitments() public view {
        uint256 expectedProtected;
        uint256 count = vault.commitmentCount();
        for (uint256 id = 1; id <= count; ++id) {
            ContinuityVault.Commitment memory commitment = vault.getCommitment(id);
            if (commitment.active) expectedProtected += uint256(commitment.amount);
        }
        assertEq(vault.protectedBalance(), expectedProtected);
    }

    function invariant_recoveryRequestOnlyExistsInContinuity() public view {
        if (vault.recoveryRequestedAt() != 0) {
            assertTrue(vault.continuityActivated());
            assertEq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
        }
    }

    function invariant_noLatchedContinuityStateHasActiveMode() public view {
        if (vault.continuityActivated()) {
            assertEq(uint256(vault.mode()), uint256(ContinuityVault.Mode.CONTINUITY));
        }
    }

    function invariant_handlerExecutedCalls() public view {
        assertTrue(handler.calls() >= handler.successfulExecutions());
    }
}
