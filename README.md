# DUREQO

Financial Continuity Infrastructure.

## Current status

Phase 9 completion scope is implemented locally. The repository contains the
`ContinuityVault` single-asset treasury contract, USDG accounting, scheduled
commitments, heartbeat-based continuity activation, authority contraction,
delayed recovery, an Arbitrum Sepolia deployment script, and adversarial,
fuzz, and invariant coverage.

DUREQO `ContinuityVault` is deployed on Arbitrum Sepolia at
`0xf5C83a79Dd3909b6989a37c3ab77653363E569D1` via deployment transaction
`0x9a4ab8a56f12d8ff8e116623cca855282ec0828449633c4676bb084a93419241`.
The deployed bytecode has an exact creation/runtime match via Sourcify.
This does not imply production readiness or a third-party security audit.
Phase 9 remains PARTIAL because the real official-USDG lifecycle is blocked by
pending Paxos destination/beneficiary approval. The deployment script is
intentionally chain-gated and requires operator-owned environment variables at
execution time.

## Repository layout

- `contracts/` — Foundry contract, tests, and deployment script
- `apps/web/` — minimal Next.js frontend foundation
- `docs/` — project documentation and audit notes

## Prerequisites

- WSL2 Ubuntu
- Node.js 24.x
- pnpm 10.x
- Foundry

## Basic commands

```bash
pnpm install
pnpm build:web
pnpm lint:web
pnpm typecheck:web
forge build --root contracts
forge test --root contracts
```

To prepare a deployment, copy `.env.example` to a private environment file,
fill in the deployer key and owner, then run the deployment script against
Arbitrum Sepolia:

```bash
forge script contracts/script/DeployContinuityVault.s.sol:DeployContinuityVault \\
  --rpc-url "$NEXT_PUBLIC_ARBITRUM_SEPOLIA_RPC_URL" \\
  --broadcast
```

The contract test suite currently covers 105 passing tests across unit,
adversarial, fuzz, and invariant suites.
