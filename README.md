# DUREQO

## Financial Continuity Infrastructure

> Pre-authorize what must survive without pre-authorizing unrestricted access.

Critical financial operations should not depend on one person remaining continuously available. DUREQO is a smart-contract vault for a third path between stopping when a controller is unavailable and granting another actor broad authority: during degraded operation, discretionary authority contracts while previously authorized critical commitments remain executable.

Its long-term direction is **financial fault tolerance for programmable organizations**.

DUREQO is not a bank, wallet, multisig, Safe replacement, inheritance system, AI treasury manager, autonomous finance agent, or guaranteed-payment system. The current MVP is deployed on Arbitrum Sepolia testnet.

## Core model

```text
ACTIVE → CAUTION → CONTINUITY → RECOVERY → ACTIVE
```

- **ACTIVE** — normal controller authority: deposits, due commitment execution, Check In, discretionary withdrawal, commitment management, and ownership-transfer initiation.
- **CAUTION** — the heartbeat has expired, but Continuity has not been activated. The controller can Check In and restore Active. Deposits and due commitment execution remain available; discretionary withdrawal, new commitments, cancellation, and new ownership-transfer initiation are blocked.
- **CONTINUITY** — after the grace threshold, any caller may activate Continuity. Discretionary authority is suspended, while previously authorized due commitments remain executable. The state is latched until recovery completes.
- **RECOVERY** — the controller requests recovery and waits through the immutable recovery delay. Successful completion restores Active with a new heartbeat. Continuity is not automatically activated merely because time passes; activation becomes permissionless only at eligibility, and the contract remains authoritative.

## How the vault works

```text
Controller Wallet
       |
       v
ContinuityVault
       |
       v
      USDG
```

The user wallet is the controller authority according to the contract. The vault holds the configured USDG asset. DUREQO itself has no separate project-admin withdrawal path capable of withdrawing user funds.

For each active commitment, exactly one stored payment amount is reserved:

```text
protectedBalance = sum(amount of each active commitment)
availableBalance = max(actual USDG balance - protectedBalance, 0)
```

Recurring commitments reserve one payment, not an infinite series of future payments. Finite capital therefore does not imply infinite recurring solvency.

### Commitments

- **One-time:** `interval == 0`. Execution pays once, deactivates the commitment, and releases its reservation.
- **Recurring:** `interval > 0`. Execution pays exactly one stored amount and sets `nextDue = block.timestamp + interval`. Missed periods are not caught up, and the reservation remains active.

Execution is permissionless, but the executor supplies only the commitment ID. Recipient and amount come from stored contract state; execution grants the executor no custody or persistent privilege.

### Authority contraction

| State | Permitted actions | Restricted actions |
| --- | --- | --- |
| ACTIVE | Deposit; due commitment execution; Check In; discretionary withdrawal; create/cancel commitments; ownership-transfer initiation | None of the degraded-state restrictions |
| CAUTION | Deposit; due commitment execution; Check In; eligible permissionless Continuity activation | Discretionary withdrawal; create commitment; cancel commitment; new ownership-transfer initiation |
| CONTINUITY | Deposit; previously authorized due commitment execution; recovery lifecycle; acceptance of an already pending owner under `Ownable2Step` | Discretionary withdrawal; new commitments; cancellation; ordinary Check In restoration; new ownership-transfer initiation |

The contract—not the frontend—is the authority boundary. See the [security model](docs/SECURITY_MODEL.md).

## USDG and deployment

The canonical MVP deployment is a **testnet** deployment:

- **Network:** Arbitrum Sepolia
- **Chain ID:** `421614`
- **ContinuityVault:** `0xf5C83a79Dd3909b6989a37c3ab77653363E569D1`
- **Deployment transaction:** `0x9a4ab8a56f12d8ff8e116623cca855282ec0828449633c4676bb084a93419241`
- **Deployment block:** `312224523`
- **Initial owner:** `0x84e0F72cE25C8a9Fa7F7A675baB38384683109ad`
- **USDG:** `0xFFC95faa3d63Cde504a05B567C600B78C0b41892`
- **Immutable timings:** heartbeat `300` seconds; grace `180` seconds; recovery delay `180` seconds

Observed official test USDG metadata: name `Global Dollar`, symbol `USDG`, decimals `6`. The official USDG financial lifecycle remains externally blocked/not tested; deployment and state-machine evidence must not be read as completed deposit-and-payment evidence.

## Repository map

```text
apps/web/                 Next.js frontend
apps/web/src/app/         / and /app routes
apps/web/src/components/ landing page, navigation, dashboard, Web3 UI
apps/web/src/lib/web3/    chain config, reads, ABI, validation, transactions
contracts/src/            ContinuityVault.sol
contracts/test/           deterministic contract tests
contracts/test/security/  fuzz, invariant, adversarial, and callback tests
contracts/script/         chain-gated deployment script
docs/                     technical evidence and security model
```

## Local development

### Requirements

- Node.js 24.x
- pnpm 10.x (`packageManager` is `pnpm@10.32.1`)
- Foundry

The repository commands are:

```bash
pnpm install
pnpm build:web
pnpm lint:web
pnpm typecheck:web
forge fmt --check
forge build --root contracts
forge test --root contracts
```

Run the frontend locally with:

```bash
pnpm --dir apps/web dev
```

Public frontend variable names are defined in [`.env.example`](.env.example): `NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL`, `NEXT_PUBLIC_USDG_ADDRESS`, and `NEXT_PUBLIC_CONTINUITY_VAULT_ADDRESS`. Deployment inputs are also named there. Put real deployment credentials only in ignored local environment files; never commit them.

The chain-gated deployment script requires operator-owned inputs at execution time:

```bash
forge script script/DeployContinuityVault.s.sol:DeployContinuityVault \
  --root contracts \
  --rpc-url "$NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL" \
  --broadcast
```

This documentation does not include credential values. Deployment is not part of normal local development.

## Evidence and limitations

The latest recorded contract regression reported 105 passing tests. No violation was observed across DUREQO's deterministic, fuzz, stateful-invariant, adversarial-sequence and callback-reentrancy tests under the defined USDG-compatible ERC-20 assumptions. This is not a formal proof or third-party audit.

- [Technical evidence](docs/TECHNICAL_EVIDENCE.md) — deployment facts, test matrix, live evidence, invariant mapping, and reproducibility.
- [Security model](docs/SECURITY_MODEL.md) — trust boundaries, authority model, attack surface, assumptions, and limitations.

Important limits include controller-key compromise, finite capital, underfunding without an implicit priority policy, permissionless-but-not-automatic Continuity activation, one configured USDG asset, testnet deployment, no production Safe/multisig recovery architecture, and the outstanding official USDG financial E2E. A2A and agents are deferred and are not part of this MVP.

## Roadmap boundary

Future work may evaluate a constrained Continuity Operator that reads vault state and calls only already-permissionless operations such as `activateContinuity()` and `executeCommitment(id)`. It must remain an operator/observer rather than financial authority. That is roadmap architecture, not current functionality.
