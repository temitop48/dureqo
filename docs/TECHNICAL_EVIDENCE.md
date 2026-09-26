# DUREQO Technical Evidence

This document records evidence for the locked MVP and separates local tests, frontend validation, deployed read-only checks, live state-machine evidence, and the outstanding official USDG financial lifecycle.

## Canonical deployment

| Field | Value |
| --- | --- |
| Network | Arbitrum Sepolia testnet |
| Chain ID | `421614` |
| ContinuityVault | `0xf5C83a79Dd3909b6989a37c3ab77653363E569D1` |
| Deployment transaction | `0x9a4ab8a56f12d8ff8e116623cca855282ec0828449633c4676bb084a93419241` |
| Deployment block | `312224523` |
| Initial owner | `0x84e0F72cE25C8a9Fa7F7A675baB38384683109ad` |
| Configured USDG | `0xFFC95faa3d63Cde504a05B567C600B78C0b41892` |
| Immutable timings | heartbeat `300s`; grace `180s`; recovery delay `180s` |

### Phase 9 read-only verification

Recorded verification found deployed bytecode, the expected owner, the expected USDG, and matching `300 / 180 / 180` timings. The initial read state was `protectedBalance = 0`, `availableBalance = 0`, `commitmentCount = 0`, and `isFunded = true`. Official test USDG reported name `Global Dollar`, symbol `USDG`, and decimals `6`.

Sourcify v2 recorded an exact creation/runtime bytecode match under verification ID `c598035d-d28f-46c3-8153-c82658efbf8f`. Sourcify verification is source/bytecode evidence; it is not a security audit.

## Contract regression

The latest recorded Phase 15 regression was:

| Category | Result |
| --- | ---: |
| Total tests | 105 passed |
| Failed | 0 |
| Skipped | 0 |
| Deterministic/unit tests | 84 |
| Fuzz tests | 12 |
| Total fuzz runs | 2,817 |
| Stateful invariant tests | 5 |
| Invariant calls | 6,400 total |
| Adversarial sequence tests | 4 |
| Callback/reentrancy tests | 2 |

No violation was observed across DUREQO's deterministic, fuzz, stateful-invariant, adversarial-sequence and callback-reentrancy tests under the defined USDG-compatible ERC-20 assumptions. This is test evidence, not a formal proof or third-party audit.

Sources: `contracts/test/ContinuityVault.t.sol`, `contracts/test/security/ContinuityVaultAttack.t.sol`, `ContinuityVaultFuzz.t.sol`, `ContinuityVaultInvariant.t.sol`, and `handlers/ContinuityVaultHandler.sol`.

The current command evidence is:

```bash
forge fmt --check
forge build --root contracts
forge test --root contracts -vv
```

| Command | Status |
| --- | --- |
| `forge build --root contracts` | PASS |
| `forge test --root contracts -vv` | PASS — 105 tests passed, 0 failed, 0 skipped |
| `forge fmt --check` | EXISTING FORMATTING DRIFT |

The formatting drift predates Phase 18 and is repository formatting/hygiene debt. It does not
change the recorded 105-test regression result and is not classified as a security finding.
The recorded build completed with warnings only; the warnings did not change the test result.

## Frontend validation

Recorded Phase 17 validation:

```bash
git diff --check
pnpm --dir apps/web lint
pnpm --dir apps/web typecheck
pnpm --dir apps/web build
```

The latest normal WSL production build for Next.js `16.3.6` recorded production compilation PASS, TypeScript PASS, page-data collection PASS, static generation `5/5`, and routes `/`, `/_not-found`, and `/app`.

A Codex sandbox Turbopack run encountered a local worker-port restriction while creating the Next.js app endpoint. That environment limitation is distinct from the recorded normal WSL production build and is not treated as an application build failure.

## Frozen invariant matrix

| ID | Property | Evidence mapping |
| --- | --- | --- |
| INV-01 | Successful discretionary withdrawal cannot consume protected capital. | `testProtectedCapitalCannotBeWithdrawn`; `testOwnerCanWithdrawExactlyAvailableBalance`; `invariant_protectedBalanceEqualsActiveCommitments` |
| INV-02 | `protectedBalance` corresponds to one reservation for every active commitment. | `testOneTimeAndRecurringReservationAccounting`; `testFuzzProtectedBalanceTracksOneReservationPerActiveCommitment`; `invariant_protectedBalanceEqualsActiveCommitments` |
| INV-03 | Continuity cannot activate before threshold. | `testActivationRejectsBeforeEligibilityAndSucceedsAtExactEligibility`; `testFuzzContinuityEligibilityBoundary` |
| INV-04 | CAUTION cannot expand authority. | `testCautionWithdrawalReverts`; `testCreateAllowedAtActiveUntilAndBlockedAfter`; `testOwnershipTransferInitiationBlockedInCautionAndContinuity` |
| INV-05 | CONTINUITY cannot expand authority. | `testContinuityFinancialBehaviorPreservesExecutionAndDeposit`; `testRecoveryDelayDoesNotExpandContinuityAuthority`; `testModeBoundariesIncludeContinuity` |
| INV-06 | Continuity outflow is confined to previously authorized commitments. | `testAdversarialLifecyclePreservesReservationsAcrossModes`; `testUnderfundedContinuityExecutesOnlyFundedCommitmentAndStillRecovers` |
| INV-07 | Executor cannot select commitment recipient. | `testRandomCallerExecutesOneTimeUsingStoredAuthority`; `testFuzzExecutorCannotRedirectStoredPayment` |
| INV-08 | Executor cannot select commitment amount. | `testRandomCallerExecutesOneTimeUsingStoredAuthority`; `testFuzzExecutorCannotRedirectStoredPayment` |
| INV-09 | A commitment cannot execute twice for the same scheduled occurrence. | `testRecurringSameOccurrenceCannotExecuteTwiceAndRunsAgainLater`; `testRecurringLongDelayHasNoCatchUpOrSameOccurrenceDoublePayment` |
| INV-10 | Execution grants the executor no custody or persistent privilege. | `testRandomCallerExecutesOneTimeUsingStoredAuthority`; `testNonOwnerDepositDoesNotGrantAuthorityOrChangeVaultState` |
| INV-11 | Deposit grants no withdrawal authority. | `testNonOwnerDepositDoesNotGrantAuthorityOrChangeVaultState`; `testNonOwnerCannotWithdrawEvenWithValidArguments` |
| INV-12 | Direct USDG transfers do not corrupt accounting. | `testDirectTransferUpdatesAvailableBalanceWithoutAuthority`; `testDirectTransferAndDepositCoexist`; `testFuzzAccountingViewsAfterInflows`; `invariant_actualBalanceViewsAreConsistent` |
| INV-13 | Recovery cannot restore unrestricted authority immediately. | `testCompleteRecoveryRequiresRequestAndExactDelay`; `testRecoveryDelayDoesNotExpandContinuityAuthority`; `testRecoveryRequiresNewHeartbeatGraceCycleBeforeReactivation` |
| INV-14 | No DUREQO/project admin can withdraw user assets. | `testNonOwnerCannotWithdrawEvenWithValidArguments`; `testProtectedCapitalCannotBeWithdrawn`; `testAdversarialLifecyclePreservesReservationsAcrossModes` |
| INV-15 | Entering Continuity never creates additional financial authority. | `testContinuityActivationPreservesFinancialAndHeartbeatState`; `testContinuityFinancialBehaviorPreservesExecutionAndDeposit`; `testAdversarialLifecyclePreservesReservationsAcrossModes` |

This matrix is evidence of tested behavior under stated assumptions, not a mathematical proof.

## Live state-machine evidence

The previously completed Arbitrum Sepolia runtime sequence was:

```text
ACTIVE → CAUTION → CONTINUITY → RECOVERY PENDING
       → CONTINUITY via cancellation → RECOVERY PENDING
       → ACTIVE via delayed completion
```

Observed behaviors included controller Check In, natural Caution after heartbeat expiry, non-controller permissionless activation, latched Continuity, controller recovery request, cancellation, a second request, the immutable delay, completion, a new heartbeat, and return to Active.

**This is LIVE STATE-MACHINE EVIDENCE. It is not completed official-USDG financial lifecycle evidence.**

## OFFICIAL USDG FINANCIAL E2E STATUS

**EXTERNAL BLOCKER / NOT TESTED**

```text
official Arbitrum Sepolia test USDG
  → controller wallet
  → exact approval
  → vault deposit
  → funded commitment
  → protected execution
  → accounting verification
```

This lifecycle must not be reported as passed. Mock USDG evidence is not a substitute. Contract tests validate financial semantics under the defined USDG-compatible ERC-20 assumptions, while the canonical deployed vault's official test-asset lifecycle remains outstanding.

## Reproducibility and cost

The MVP was built and tested using free/open-source tooling and public/testnet infrastructure. No paid RPC, scanner, SaaS, or audit service is required for the documented local commands. This does not claim future operation or transaction fees would be permanently free.
