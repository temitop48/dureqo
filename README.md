# DUREQO

Financial Continuity Infrastructure.

## Current status

Phase 1 contains development foundation only. No contracts, deployment, Arbitrum integration, USDG integration, or Continuity functionality has been implemented.

## Repository layout

- `contracts/` — Foundry project foundation
- `apps/web/` — minimal Next.js frontend foundation
- `docs/` — documentation placeholder

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

No production-readiness, security, deployment, or integration claims are made by this repository.
