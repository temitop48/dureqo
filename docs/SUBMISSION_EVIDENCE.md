# DUREQO Submission Evidence Manifest

This manifest separates verified onchain facts, verified test evidence,
live USDC validation evidence, USDG integration status, product/design
claims, and current limitations. Partial or blocked evidence is not
represented as completed functionality.

## 1. Project identity

**Evidence class: PRODUCT/DESIGN CLAIM**

- **Project:** DUREQO
- **Category:** Financial Continuity Infrastructure
- **Core proposition:** “Pre-authorize what must survive without
  pre-authorizing unrestricted access.”
- **Preferred judge-facing line:** “DUREQO protects an organization from
  key-person financial failure without creating a new master key.”
- **Core mechanism:** Authority Contraction.

Authority Contraction means that as operational certainty decreases,
discretionary financial authority contracts while previously authorized
critical obligations can remain executable.

DUREQO is not presented as a generic recurring-payment app, dead-man-switch
payment app, wallet, bank, inheritance system, AI treasury manager, or escrow
product.

## 2. Canonical Arbitrum deployment

**Evidence class: VERIFIED ONCHAIN FACT**

| Field | Value |
| --- | --- |
| Network | Arbitrum Sepolia |
| Chain ID | `421614` |
| Canonical ContinuityVault | `0xf5C83a79Dd3909b6989a37c3ab77653363E569D1` |
| Canonical asset | Paxos test USDG |
| USDG | `0xFFC95faa3d63Cde504a05B567C600B78C0b41892` |
| Owner/controller | `0x84e0F72cE25C8a9Fa7F7A675baB38384683109ad` |
| Deployment transaction | `0x9a4ab8a56f12d8ff8e116623cca855282ec0828449633c4676bb084a93419241` |
| Deployment block | `312224523` |
| heartbeatInterval | `300` seconds |
| gracePeriod | `180` seconds |
| recoveryDelay | `180` seconds |
| Deployment gas | `1,617,015` |
| Deployment cost | `0.000078425229117015 ETH` |
| Sourcify | Exact creation/runtime bytecode match |
| Verification ID | `c598035d-d28f-46c3-8153-c82658efbf8f` |

The canonical vault is deployed and configured for official Paxos Arbitrum
Sepolia test USDG. Deployment and bytecode verification do not establish
that the canonical USDG financial lifecycle has completed.

## 3. Canonical USDG lifecycle status

**CANONICAL USDG FINANCIAL E2E: EXTERNAL DISTRIBUTION BLOCKER / NOT COMPLETED**

**Evidence class: USDG INTEGRATION STATUS / CURRENT LIMITATION**

Verified official USDG facts:

| Field | Value |
| --- | --- |
| Contract | `0xFFC95faa3d63Cde504a05B567C600B78C0b41892` |
| Name | `Global Dollar` |
| Symbol | `USDG` |
| Decimals | `6` |
| Controller USDG balance | `0` |
| Canonical vault USDG balance | `0` |
| Canonical vault allowance from controller | `0` |
| Canonical vault protectedBalance | `0` |
| Canonical vault availableBalance | `0` |
| Canonical vault commitmentCount | `0` |

Existing Paxos Sandbox withdrawal:

| Field | Value |
| --- | --- |
| ID | `d9f76493-7e93-4abc-8dcd-f673aaa0cc8f` |
| Reference | `dureqo-phase9-usdg-1790289112` |
| Amount | `10 USDG` |
| Fee | `0.01 USDG` |
| crypto_network | `ARBITRUM_ONE` |
| Destination | `0x84e0F72cE25C8a9Fa7F7A675baB38384683109ad` |
| Status | `PENDING` |
| Created | `2026-09-24T22:31:55.768100Z` |
| Last observed update | `2026-09-25T12:31:06.594674Z` |
| Blockchain transaction hash | None returned |
| Failure reason | None returned |

The pending Paxos transfer has not produced a blockchain transaction hash,
and no official test USDG has reached the controller. This manifest does not
blame Paxos, speculate about the cause, or claim USDG E2E completion.

## 4. Parallel USDC validation deployment

**Evidence class: VERIFIED ONCHAIN FACT / LIVE USDC VALIDATION EVIDENCE**

The second deployment is a parallel validation track for the unchanged,
frozen ContinuityVault implementation. It does not change the canonical USDG
deployment or introduce a multi-token vault architecture.

| Field | Value |
| --- | --- |
| Network | Arbitrum Sepolia |
| Chain ID | `421614` |
| Validation vault | `0x777af44D1C8dC0088f5445994c266769aC200659` |
| Official test USDC | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` |
| Owner/controller | `0x84e0F72cE25C8a9Fa7F7A675baB38384683109ad` |
| Deployment transaction | `0x291f2012f487d8ee0e3d4fbc473a43a5199a7ce5a2d305156aa5d3c32698d5b8` |
| Deployment block | `313298230` |
| Gas | `1,629,294` |
| Fee | `0.000050856784545294 ETH` |

Production Solidity was unchanged. The same frozen ContinuityVault
implementation was used. Each vault still has one immutable configured asset;
no multi-token accounting or arbitrary token selection was introduced. USDC
validation is not USDG E2E validation.

## 5. Live USDC lifecycle

**Evidence class: LIVE USDC VALIDATION EVIDENCE**

### Funding and reserve establishment

- Initial controller balance: `40 USDC`.
- Exact approval: `30 USDC`.
- Approval transaction:
  `0x56808790ab1fe05ca6908dc4820d132b34e593804a9b488061087cfa86316766`.
- Deposit: `30 USDC`.
- Deposit transaction:
  `0xddbb5e4d3d9d9b7378d1200a03857f5ac4249563ff54b3686525f052b1ad0190`.

After deposit:

| Vault balance | protectedBalance | availableBalance |
| ---: | ---: | ---: |
| `30 USDC` | `0 USDC` | `30 USDC` |

### Three protected recurring commitments

All three commitments use the controller as recipient and a 30-day interval.

| Label | Amount | Interval | ID | Creation transaction |
| --- | ---: | ---: | --- | --- |
| Payroll | `12 USDC` | `2,592,000` seconds | `1` | `0x5c7033d8ca003d830b6b627506db1fa3f80ca39dfbb289efeac797322d88f262` |
| Infrastructure | `4 USDC` | `2,592,000` seconds | `2` | `0x97c92c28ea9884ced5a800c52c130cea2cad43ae6a7dbcb7e52b0432cc613493` |
| Contractor | `3 USDC` | `2,592,000` seconds | `3` | `0x1036b663a331205c1e6ac3d4094a6414672eae13dcf09649940d6fac24ac799c` |

Result:

| Vault balance | protectedBalance | availableBalance | isFunded |
| ---: | ---: | ---: | --- |
| `30 USDC` | `19 USDC` | `11 USDC` | `true` |

For presentation purposes only, **Continuity Reserve = 19 USDC**. This is
product language for the existing `protectedBalance`, not a separate contract
primitive, storage field, event, or accounting concept.

## 6. Live Authority Contraction

**Evidence class: LIVE USDC VALIDATION EVIDENCE**

Continuity activation transaction:

`0x95c07c972bbb33016e0063e9e4cb3ef5ac3742cd4966adac4ed4a4a6616945ac`

- Activation block: `313396252`.
- Activation timestamp: `1790545275`.
- After activation: `mode = CONTINUITY` and `continuityActivated = true`.

The discretionary withdrawal test `withdrawAvailable(controller, 1 USDC)` was
blocked with `NotActiveMode`. The call was rejected during estimation/
simulation before broadcast, so there is no failed transaction hash.

Financial state remained:

- Vault: `30 USDC`.
- protectedBalance: `19 USDC`.
- availableBalance: `11 USDC`.
- Commitments: `3`.

This is live evidence for Authority Contraction: entering Continuity does not
create additional financial authority, and discretionary withdrawal is
blocked while previously authorized obligations remain executable.

## 7. Protected payment during Continuity

**Evidence class: LIVE USDC VALIDATION EVIDENCE**

Payroll commitment ID `1` executed during Continuity:

| Field | Value |
| --- | --- |
| Transaction | `0x2a6600603bd4d811f2f10fe555629974c5f86c39416a255ae21b7aec43215024` |
| Block | `313397495` |
| Timestamp | `1790545590` |
| Payment | `12 USDC` |

| State | Vault | Recipient/controller | protectedBalance | availableBalance | isFunded |
| --- | ---: | ---: | ---: | ---: | --- |
| Before | `30 USDC` | `10 USDC` | `19 USDC` | `11 USDC` | `true` |
| After | `18 USDC` | `22 USDC` | `19 USDC` | `0 USDC` | `false` |

Payroll remained active. Its stored next due time became `1793137590`,
matching the frozen recurring semantics:

```text
1790545590 + 2592000 = 1793137590
```

Recurring execution pays one stored payment and schedules the next occurrence
from execution time. There is no catch-up/arrears loop. The executor did not
select the recipient or amount. The resulting underfunded state is expected:
finite capital does not imply infinite recurring funding.

## 8. Delayed recovery

**Evidence class: LIVE USDC VALIDATION EVIDENCE**

| Field | Value |
| --- | --- |
| Recovery request transaction | `0x6bcb89427d7d9cee74b0e7b21822ec91708cacee6199be171ed0c2e438e6f1f6` |
| Request block | `313399440` |
| Request timestamp | `1790546076` |
| recoveryEligibleAt | `1790546256` |
| Immediate completeRecovery | Blocked |
| Observed revert | `RecoveryDelayNotElapsed(1790546256)` |
| Immediate attempt broadcast | `NO` |
| First observed eligible timestamp | `1790546262` |
| Recovery completion transaction | `0x80864d135a6ea87a7e00ddd22b135f553506e9f1e644642387a0c260e972919b` |
| Completion block | `313400676` |
| Completion timestamp | `1790546389` |

Final recovery state:

- `mode = ACTIVE`.
- `continuityActivated = false`.
- `recoveryRequestedAt = 0`.
- `lastHeartbeat = 1790546389`.
- Vault: `18 USDC`.
- protectedBalance: `19 USDC`.
- availableBalance: `0`.
- `isFunded = false`.
- `commitmentCount = 3`.

Recovery restored operational authority but did not fabricate capital.

## 9. Security test evidence

**Evidence class: VERIFIED TEST EVIDENCE**

| Test category | Result |
| --- | ---: |
| Deterministic unit tests | `84` |
| Fuzz tests | `12` |
| Stateful invariant tests | `5` |
| Adversarial attack-sequence tests | `4` |
| Total tests | `105` |
| Failed | `0` |
| Skipped | `0` |
| Observed fuzz runs | `2,817` |
| Observed invariant calls | `6,400` |
| Callback/reentrancy scenarios | `2` |

No violation was observed across DUREQO's deterministic, fuzz, stateful-
invariant, adversarial-sequence and callback-reentrancy tests under the
defined USDG-compatible ERC-20 assumptions.

This is test evidence, not formal verification, a mathematical proof,
an independent security audit, or a claim of perfect security.

## 10. Security architecture summary

**Evidence class: PRODUCT/DESIGN CLAIM grounded in the frozen architecture**

| Component | Boundary |
| --- | --- |
| Frontend | Untrusted presentation and transaction-request layer |
| Backend | Untrusted; not financial authority |
| Database | Untrusted; not financial authority |
| Agents/A2A | Untrusted and constrained; deferred in the MVP |
| User wallet | Controller authority according to the contract |
| ContinuityVault | Financial source of truth and authority boundary |
| Arbitrum | Settlement layer |
| Stablecoin | Configured asset |

The frozen MVP includes no arbitrary calls, `delegatecall`, upgradeability,
protocol superadmin, emergency withdrawal admin, arbitrary token selection, or
unrestricted executor authority. External token interactions use
`SafeERC20`. Ownership uses two-step ownership, and ownership renunciation is
disabled.

## 11. Core invariants

**Evidence class: VERIFIED TEST EVIDENCE**

The following 15 invariants are reproduced conservatively from the frozen
security documentation. They describe tested behavior under stated
assumptions, not mathematical proof.

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

## 12. Known limitations

**Evidence class: CURRENT LIMITATION**

- Owner-key compromise is not solved by the recovery delay.
- Production independent recovery is future work.
- Finite capital cannot guarantee infinite recurring obligations.
- Underfunded commitments have no implicit priority.
- Continuity activation is permissionless but not automatic.
- Canonical USDG financial E2E remains blocked/not completed.
- The USDC lifecycle is a parallel validation track, not USDG E2E.
- The current deployment is Arbitrum Sepolia testnet.
- Each vault has one immutable configured asset.
- A2A is deferred and agents are not implemented in the MVP.
- Production Safe/multisig recovery integration is future work.
- Tests are not formal proof or an independent audit.

## 13. Submission-safe claims

| Claim | Status | Evidence |
| --- | --- | --- |
| Deployed on Arbitrum Sepolia | VERIFIED | Canonical deployment facts in Section 2 |
| Canonical vault configured for official test USDG | VERIFIED | Onchain asset, owner, bytecode, and metadata reads |
| USDG E2E lifecycle completed | NOT VERIFIED / DO NOT CLAIM | Controller and vault balances are zero; Paxos withdrawal remains pending |
| Same frozen vault implementation completed live stablecoin lifecycle with official test USDC | VERIFIED | Parallel deployment and live lifecycle in Sections 4–8 |
| Discretionary withdrawal blocked in Continuity | VERIFIED LIVE | `NotActiveMode` during Stage C estimation |
| Previously authorized recurring payment executed in Continuity | VERIFIED LIVE | Payroll execution in Section 7 |
| Immediate recovery blocked | VERIFIED LIVE | `RecoveryDelayNotElapsed(1790546256)` in Section 8 |
| Delayed recovery completed | VERIFIED LIVE | Recovery completion in Section 8 |
| 105 security tests passing | VERIFIED | Section 9: 105 passed, 0 failed, 0 skipped |
| Independent security audit completed | NOT VERIFIED / DO NOT CLAIM | No independent audit evidence |
| Validated product-market fit | NOT VERIFIED / DO NOT CLAIM | No product-market-fit evidence is represented here |

## 14. Demo evidence sequence

This is evidence guidance, not marketing exaggeration:

1. Human key-person failure problem.
2. Funded treasury and protected commitments.
3. Heartbeat degradation.
4. Continuity activation.
5. Discretionary withdrawal **BLOCKED**.
6. Protected Payroll **SUCCESS**.
7. Underfunding honestly surfaced.
8. Recovery requested.
9. Immediate recovery **BLOCKED**.
10. Delayed recovery **SUCCESS**.
11. Return to **ACTIVE**.

## Evidence boundary

The canonical USDG deployment proves deployment/configuration and read-only
integration facts. The live financial lifecycle evidence in this manifest is
from the separately deployed official test-USDC validation vault using the
same unchanged single-asset ContinuityVault implementation. The USDC evidence
must not be presented as completed canonical USDG E2E.
