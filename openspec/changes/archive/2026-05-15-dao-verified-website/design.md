# Design: DAO-Verified Website

## Technical Approach

Six capability domains → three runtime layers:

| Layer | Components | Domains |
|-------|-----------|---------|
| Governance | OZ Governor + TimelockController + EmergencyGovernor | dao-governance, release-proposal, ens-timelock |
| Ceremony | Docker + TypeScript CLI | deterministic-build, ipfs-deployment |
| Frontend | Next.js static export + ethers.js v6 | frontend-base |

Contracts on **Base Sepolia**. ENS domain owned by TimelockController. Governor proposes CID updates → Timelock enforces 15d delay → ENS `setContentHash` executes. Users verify via static frontend: on-chain CID vs IPFS-served CID.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|-------------|-----------|
| L2 network | Base Sepolia | Optimism Sepolia | Stronger ENS tooling, larger L2 user base |
| DAO framework | OZ Governor + TimelockController | Custom DAO, Multisig | Battle-tested, audited, standard OZ pattern |
| Release encoding | Governor → Timelock → `ENSResolver.setContentHash` | Separate ReleaseProposal contract | Fewer contracts, simpler deploy, native OZ |
| Emergency path | 2nd Governor (2x quorum, canceller role on Timelock) | Modular Governor | Clear on-chain distinction, separate params |
| Monorepo | pnpm workspaces (3 packages) | Turborepo, Nx | Minimal tooling, strict dep management |
| Data source | ethers.js direct L2 RPC | TheGraph, Ponder | Zero infra to maintain for MVP |
| Build determinism | Docker + pinned images + offline mode | Nix, Bazel | Widest auditor familiarity |
| CID computation | Pure-JS via `@ipld/dag-cbor` | Kubo daemon | No IPFS node needed; deterministic |

## Data Flow

```
=== RELEASE FLOW ===

Builder ──→ Docker build ──→ out/ ──→ CLI computes CID
                                           │
                                     buildProposalCalldata(CID)
                                           │
                                     Governor propose() (48h vote)
                                           │
                                     TimelockController.schedule() (15d)
                                           │
                                     TimelockController.execute()
                                           │
                                     ENS setContentHash(contenthash)
                                           │
                                     CLI uploads out/ to IPFS

=== VERIFICATION FLOW ===

User browser ──→ IPFS gateway ──→ loads static Next.js page
                     │
               ethers.js BrowserProvider → L2 RPC
                     │
               ENS resolver.contenthash()
                     │
               CID match? ──→ Green "Verified" / Red "Unverified"
```

## File Changes

All files are NEW (greenfield project):

| File | Description |
|------|-------------|
| `pnpm-workspace.yaml` | Workspace: contracts, frontend, ceremony |
| `package.json` | Root workspace config |
| `contracts/foundry.toml` | Foundry config targeting Base Sepolia |
| `contracts/src/DAOGovernor.sol` | OZ Governor + GovernorSettings + TimelockController |
| `contracts/src/EmergencyGovernor.sol` | 2x quorum Governor, canceller on Timelock |
| `contracts/script/Deploy.s.sol` | Foundry deploy script (all contracts) |
| `contracts/test/Governance.t.sol` | Join/vote/quorum/timelock tests |
| `contracts/test/ReleaseProposal.t.sol` | CID proposal → ENS update tests |
| `contracts/test/Emergency.t.sol` | Emergency overwrite tests |
| `frontend/next.config.ts` | `output: "export"` for static IPFS |
| `frontend/src/app/page.tsx` | Main page: wallet + ENS + verification |
| `frontend/src/components/WalletConnect.tsx` | Connect button, network switch |
| `frontend/src/components/VerificationBadge.tsx` | Verified/Unverified badge |
| `frontend/src/lib/ens.ts` | ethers.js ENS resolver helper |
| `ceremony/Dockerfile` | Pinned `node:20-slim`, offline build |
| `ceremony/src/index.ts` | CLI entry: build → cid → upload → submit |
| `ceremony/src/cid.ts` | Pure-JS CID computation |
| `ceremony/src/submit.ts` | ethers.js tx builder for proposals |
| `ceremony/src/ipfs.ts` | IPFS upload + pin helper |

## Interfaces / Contracts

```solidity
// DAOGovernor.sol — key contstructor params
// GovernorSettings: votingDelay=1 block, votingPeriod=72h,
//   quorum=4% of total supply, proposalThreshold=1e18

// Release proposal calldata pattern:
// target = ENS public resolver address
// data = abi.encodeWithSignature(
//   "setContenthash(bytes32)", contenthash(bytes(CID))
// )
// This calldata is wrapped in TimelockController.schedule()
```

```typescript
// ceremony/src/cid.ts
function computeCID(buildDir: string): Promise<CID>

// ceremony/src/submit.ts
function buildProposalCalldata(cid: BytesLike): ProposalDescription
// Returns { target, value, data } for Governor propose()

// ceremony/src/ipfs.ts
async function uploadToIPFS(dir: string): Promise<CID>
async function pinCID(cid: CID): Promise<void>
```

```typescript
// frontend/src/lib/ens.ts
async function resolveContentHash(
  provider: BrowserProvider, ensName: string
): Promise<string | null>

async function getPageCID(): Promise<string | null>
// Reads CID from IPFS gateway headers or __NEXT_DATA__
```

```dockerfile
# ceremony/Dockerfile
FROM node:20-slim@sha256:<pinned>
WORKDIR /app
COPY pnpm-lock.yaml ./
RUN pnpm fetch --offline
COPY . .
RUN pnpm install --offline
RUN pnpm --filter frontend build  # produces frontend/out/
```

## Testing Strategy

| Layer | Scope | Tools | Key Tests |
|-------|-------|-------|-----------|
| Contracts | Governor, Timelock, ENS | Foundry fuzz + forge-std | join/vote/quorum, timelock delay enforcement, CID update, emergency overwrite, non-member rejection |
| Ceremony | Build determinism, CID | Vitest | same commit → same CID across 2 runs, offline build succeeds, CID mismatch aborts submission |
| Frontend | ENS read, badge | Vitest + @testing-library/react | contenthash resolution, network mismatch, verified/unverified badge states, no-wallet fallback |

**Integration test**: Deploy to Base Sepolia testnet → ceremony builds + uploads → frontend loads via IPFS gateway → badge matches expected CID.

## Migration / Rollout

1. **Testnet deploy**: Solidity contracts to Base Sepolia testnet via Foundry script
2. **ENS registration**: Register domain on testnet, transfer ownership to TimelockController
3. **Ceremony validation**: Build "hello world" frontend → compute CID → verify deterministic
4. **Dry-run proposal**: CLI submits ReleaseProposal → vote with test wallets → fast-forward timelock (set testnet delay to 1min) → verify ENS updates
5. **Testnet integration**: Upload `out/` to IPFS → load via gateway → verify badge
6. **Mainnet**: Repeat same contracts on Base L2 mainnet, real 15d timelock, real DAO member onboarding

**Rollback**: Within timelock window, Governor cancels pending operation. Post-execution, new ReleaseProposal reverts CID (full cycle). EmergencyGovernor overwrites with 2x quorum.

## Open Questions

- [ ] Default IPFS gateway: `dweb.link`, `cf-ipfs.com`, or configurable?
- [ ] Gas budget estimate for Governor proposals + Timelock execute on Base L2
- [ ] ENS resolver to use: public resolver or custom? Public resolver has `setContenthash` built-in.
