# DUREQO Security Model

This document describes the security boundaries and tested assumptions of the locked DUREQO MVP. It is a threat model and evidence guide, not a security certification.

## Architecture and trust boundaries

```text
Frontend ─── Backend ─── Database
    |           |           |
    +────── Controller Wallet
                    |
                    v
             ContinuityVault
                    |
                    v
                   USDG
                    |
                    v
                 Arbitrum
```

| Component | Security role |
| --- | --- |
| Frontend | Untrusted presentation and transaction-request layer |
| Backend | Untrusted; not financial authority |
| Database | Untrusted; not financial authority |
| Agent/A2A | Untrusted and constrained; not implemented in the MVP |
| User wallet | Cryptographic controller authority according to the contract |
| ContinuityVault | Financial source of truth and authority boundary |
| Arbitrum | Settlement layer |
| USDG | Configured asset layer |

Compromising the frontend, server, database, or a future agent alone should not create contract-level authority to withdraw protected or discretionary funds. A malicious frontend can still deceive a controller into signing a contract-permitted transaction, so frontend compromise is not harmless.

## Authority contraction

```text
ACTIVE → CAUTION → CONTINUITY
```

ACTIVE permits deposits, Check In, withdrawal of available funds, commitment creation/cancellation, and ownership-transfer initiation. Due commitments are permissionless to execute.

CAUTION retains deposits, due commitment execution, Check In, and eligible permissionless Continuity activation. Withdrawal, commitment creation, cancellation, and new ownership-transfer initiation are blocked.

CONTINUITY retains deposits, already authorized due commitment execution, recovery lifecycle actions, and acceptance of an already pending owner according to current `Ownable2Step` behavior. Withdrawal, new commitments, cancellation, ordinary Check In restoration, policy expansion, and new ownership-transfer initiation are blocked.

Continuity activation does not create authority. The executor supplies only a commitment ID; recipient and amount come from stored contract state.

## State-machine boundary semantics

The contract computes:

```text
activeUntil = lastHeartbeat + heartbeatInterval
continuityEligibleAt = activeUntil + gracePeriod
```

If Continuity is not latched:

```text
timestamp <= activeUntil  → ACTIVE
timestamp > activeUntil   → CAUTION
```

At exactly `timestamp == continuityEligibleAt`, mode remains CAUTION, but `activateContinuity()` is permitted. After successful activation, the mode is CONTINUITY and the latch remains set.

Continuity is not automatic merely because time passes. Any caller may activate it once eligible. `checkIn()` cannot restore Active from Continuity; recovery must be used.

```text
CONTINUITY
    │ owner requests recovery
    v
RECOVERY PENDING ── owner cancels ──> CONTINUITY
    │ immutable recovery delay elapses
    v
ACTIVE with a new heartbeat
```

Completion cannot bypass the delay and writes a fresh heartbeat only when recovery completes.

## Accounting model

The vault reads capital directly from the configured token:

```text
actual balance = USDG.balanceOf(address(this))
availableBalance = max(actual balance - protectedBalance, 0)
```

There is no internal `vaultBalance`. Direct USDG transfers increase capital without granting authority. Creating a commitment requires enough current capital for its one stored reservation. A recurring commitment may become underfunded later.

When underfunded, `availableBalance = 0`. There is no implicit commitment priority: any due commitment may execute if actual balance covers its stored amount. DUREQO does not claim guaranteed recurring solvency.

- A one-time commitment releases its reservation on execution or cancellation.
- A recurring commitment reserves one amount, pays once, then sets `nextDue = block.timestamp + interval`; missed periods do not create catch-up payments.
- Permissionless execution does not transfer custody or change recipient or amount.

## Ownership and recovery

Ownership uses OpenZeppelin `Ownable2Step`. Renouncing ownership is disabled. New ownership-transfer initiation is ACTIVE-only. Acceptance by an already pending owner remains available in degraded modes, preserving pre-authorized succession semantics under current contract behavior.

The recovery delay does **not** solve owner-key compromise. A compromised legitimate controller key remains a major threat because it can use whatever authority the current mode permits. Production independent recovery, multisig, or Safe integration belongs to future architecture.

## Attack surface intentionally excluded from V1

The MVP intentionally excludes:

- arbitrary external calls;
- `delegatecall`;
- arbitrary calldata;
- arbitrary token selection;
- arbitrary target selection;
- upgradeability;
- proxy admin;
- protocol superadmin;
- emergency withdrawal admin;
- Pausable authority;
- unrestricted ownership renunciation.

Token interactions are narrowly scoped to immutable USDG and use OpenZeppelin `SafeERC20`. State-changing token transfer paths use OpenZeppelin `ReentrancyGuard` on `deposit`, `withdrawAvailable`, and `executeCommitment`. Callback/reentrancy coverage includes `testTokenCallbackCannotReenterDeposit(uint128)` and `testTokenCallbackCannotReenterExecution()`.

## ERC-20 assumptions

Security tests assume trusted USDG-compatible ERC-20 behavior. DUREQO V1 is not generalized to arbitrary ERC-20s.

- Fee-on-transfer tokens are outside the current asset model.
- Rebasing tokens are outside the current asset model.
- ERC777-style callback behavior is outside the intended asset model, while callback/reentrancy behavior has specific adversarial coverage where applicable.
- The deployed vault has one immutable configured USDG asset; callers cannot select another token.

## Frozen security evidence

The latest recorded regression was 105 passing tests: 84 deterministic/unit, 12 fuzz, 5 stateful-invariant, 4 adversarial-sequence, and 2 callback/reentrancy tests, with 2,817 total fuzz runs and 6,400 invariant calls. No violation was observed across DUREQO's deterministic, fuzz, stateful-invariant, adversarial-sequence and callback-reentrancy tests under the defined USDG-compatible ERC-20 assumptions. This is not a formal proof or third-party audit.

See [Technical Evidence](TECHNICAL_EVIDENCE.md) for the full invariant matrix, deployment facts, commands, and live state-machine evidence.

## Agents and A2A

**Phase 16 decision: A2A DEFERRED.** A2A and agents are not implemented in the MVP.

Roadmap architecture:

```text
DUREQO Vault
      → Read-only monitoring layer
      → Constrained Continuity Operator
      → A2A interface
      → External agents/services
```

The maximum intended operator calls are `activateContinuity()` and `executeCommitment(id)`. The operator must have no ownership, custody, withdrawals, commitment creation, commitment cancellation, recovery authority, arbitrary transaction routing, recipient selection, or amount selection.

This is roadmap architecture only, not current functionality.

## Limitations

1. Owner-key compromise is not solved by the recovery delay.
2. Finite capital cannot guarantee infinite recurring obligations.
3. Underfunding has no implicit commitment priority.
4. Continuity activation is permissionless after eligibility, but not automatic.
5. Official USDG financial E2E remains externally blocked/not tested.
6. The current deployment is Arbitrum Sepolia testnet.
7. V1 supports one configured USDG asset, not arbitrary tokens.
8. A2A and agents are not implemented.
9. No production Safe/multisig recovery architecture exists yet.
10. Test evidence is not a formal proof or third-party audit.

These limitations are part of the MVP's security boundary and should be considered before interpreting its test or deployment evidence.

