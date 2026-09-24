# Documentation

## Phase 9 audit scope

The current implementation covers:

- single-asset USDG deposits and actual-balance accounting;
- owner-controlled available-balance withdrawals while `ACTIVE`;
- funded one-time and recurring commitments with permissionless execution;
- heartbeat, `ACTIVE` → `CAUTION` → `CONTINUITY` state transitions;
- owner authority contraction after continuity activation;
- two-step ownership transfer with renunciation disabled;
- delayed, cancellable recovery requiring a fresh heartbeat cycle after recovery.

The contract is deployed on Arbitrum Sepolia at
`0xf5C83a79Dd3909b6989a37c3ab77653363E569D1` via deployment transaction
`0x9a4ab8a56f12d8ff8e116623cca855282ec0828449633c4676bb084a93419241`, and its
deployed bytecode has an exact creation/runtime match via Sourcify. The
deployment does not imply production readiness or a third-party security audit.
The contract is tested locally with 84 unit tests, 4 adversarial tests, 12 fuzz
tests, and 5 invariant tests. Phase 9 remains PARTIAL because the real official-
USDG lifecycle is blocked by pending Paxos destination/beneficiary approval.

See the repository README for local commands and the Arbitrum Sepolia
deployment procedure.
