# Tasks: DAO-Verified Website Platform

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 900–1300 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Contracts → PR 2: Ceremony → PR 3: Frontend → PR 4: CI+Docs |
| Delivery strategy | ask-on-risk → chained |
| Chain strategy | stacked-to-main |
| Resolved by | user (orchestrator prompt) |

Decision needed before apply: Yes (resolved)
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Workspace + Solidity contracts + Foundry tests | PR 1 | Base = main; infra, DAOGovernor, EmergencyGovernor, Deploy, tests |
| 2 | Ceremony CLI + determinism tests | PR 2 | Depends on PR 1 (contracts ABI for calldata); Dockerfile, cid.ts, submit.ts, ipfs.ts |
| 3 | Frontend + component tests | PR 3 | Depends on PR 1 (ENS addresses); static Next.js, ENS reads, verify badge |
| 4 | CI pipeline + README | PR 4 | Depends on prior; GitHub Actions, docs |

## Phase 1: Foundation

- [x] 1.1 Create `pnpm-workspace.yaml` and root `package.json` for 3-package monorepo
- [x] 1.2 Create `contracts/foundry.toml` targeting Base Sepolia, import OZ Contracts v5 (+ `contracts/package.json`)
- [x] 1.5 Create `.gitignore` for contracts/node_modules/build artifacts
- [x] 1.3 Create `frontend/package.json` + `frontend/next.config.ts` with `output: "export"` + `frontend/tsconfig.json` + `frontend/vitest.config.ts`
- [x] 1.4 Create `ceremony/package.json` + `ceremony/tsconfig.json` + `ceremony/Dockerfile` (pinned node:20-slim)

## Phase 2: Solidity Contracts

- [x] 2.1 Write `contracts/src/dao/GovernorDAO.sol` — OZ Governor + GovernorSettings + TimelockController wiring (+ DAOShare voting token)
- [x] 2.4 Write `contracts/src/lib/Interfaces.sol` — IENSPublicResolver + IReleaseRecorder interfaces
- [x] 2.5 Write `contracts/src/ens/ENSResolver.sol` — Timelock-controlled ENS content hash wrapper
- [x] 2.6 Write `contracts/src/releases/ReleaseProposal.sol` — release proposal recorder
- [x] 2.2 Write `contracts/src/dao/EmergencyGovernor.sol` — 2x quorum, canceller role on Timelock
- [x] 2.3 Write `contracts/script/Deploy.s.sol` — deploy all contracts and configure roles

## Phase 3: Ceremony CLI

- [x] 3.1 Write `ceremony/src/cid.ts` — pure-JS CID computation via @ipld/dag-pb + ipfs-unixfs
- [x] 3.2 Write `ceremony/src/submit.ts` — buildProposalCalldata() for ENS setContenthash + ReleaseProposal.recordRelease
- [x] 3.3 Write `ceremony/src/ipfs.ts` — uploadToIPFS() + pinCID() helpers (via Kubo RPC)
- [x] 3.4 Write `ceremony/src/index.ts` — CLI entry with commander: build, verify, ipfs, submit subcommands

## Phase 4: Frontend

- [x] 4.1 Write `frontend/src/lib/ens.ts` — resolveContentHash() + getPageCID() via ethers.js v6 (+ `frontend/src/lib/contracts.ts`, `frontend/src/lib/verify.ts`, `frontend/src/lib/wallet.tsx`, `frontend/src/config.ts`)
- [x] 4.2 Write `frontend/src/components/WalletButton.tsx` + `frontend/src/lib/wallet.tsx` — BrowserProvider connect + network switch (React context)
- [x] 4.3 Write `frontend/src/components/VerifyBadge.tsx` — green "Verified" / red "Unverified"
- [x] 4.4 Write `frontend/src/app/page.tsx` — compose wallet + ENS read + badge display + on-chain details

## Phase 5: Tests

- [x] 5.1 Write `contracts/test/DAOGovernor.t.sol` — join/vote/quorum/timelock (Foundry)
- [x] 5.2 Write `contracts/test/ReleaseProposal.t.sol` — release recording + role enforcement (Foundry)
- [x] 5.4 Write `contracts/test/ENSResolver.t.sol` — contenthash set/access control/events (Foundry)
- [x] 5.3 Write `contracts/test/EmergencyGovernor.t.sol` — emergency quorum + cancellation tests (Foundry)
- [x] 5.4 Write ceremony Vitest tests — determinism, CID mismatch abort, offline build success
- [x] 5.5 Write frontend Vitest+RTL tests — contenthash resolution, badge states, wallet button smoke test

## Phase 6: CI & Docs

- [x] 6.1 Create `.github/workflows/ci.yml` — Foundry forge test + ceremony build + frontend build
- [x] 6.2 Write `README.md` — setup, ceremony flow, deploy steps, architecture overview
