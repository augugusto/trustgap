# Proposal: DAO-Verified Website Platform

## Intent

DAO-controlled ENS + timelock + cryptographic verification that deployed content matches approved source. Target: activists in authoritarian regimes needing anonymity.

## Scope

### In Scope
- DAO governance (OZ Governor) with shares-based membership
- ENS controlled by DAO via TimelockController
- ReleaseProposal: propose CID → vote → 15d timelock → auto-update ENS
- Static Next.js "hello world" with wallet connect, IPFS-served
- Manual ceremony: Docker deterministic build → compute CID
- L2 testnet (Base/Optimism), Radicle source repo

### Out of Scope
- TheGraph/Ponder indexer, automated ceremony, pinning incentives
- Complex frontend, production L2

## Capabilities

### New Capabilities
- `dao-governance`: DAO membership, proposals, voting, quorum via OZ Governor
- `ens-timelock-control`: ENS owned by TimelockController, atomic updates after delay
- `release-proposal`: CID proposals with vote→timelock→auto-execute ENS update
- `deterministic-build`: Docker pipeline for reproducible artifacts
- `ipfs-deployment`: Static site to IPFS with CID verification
- `frontend-base`: Next.js static export + ethers.js wallet

### Modified Capabilities

None.

## Approach

**Contracts** (Solidity + Foundry): OZ Governor + TimelockController owns ENS. ReleaseProposal enforces vote→timelock→ENS update.

**Frontend** (Next.js + ethers.js v6): Read-only. Verify ENS CID against IPFS. No server.

**Ceremony** (Docker + TypeScript): Deterministic build → CID → CLI submit.

Source in Radicle. L2 for lower gas.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `contracts/` | New | Governor, Timelock, ENS, ReleaseProposal |
| `frontend/` | New | Next.js export + wallet + IPFS verify |
| `ceremony/` | New | Docker build + CID + CLI |
| `radicle/` | New | Repo config and push workflow |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Browser ENS+IPFS unreliable | High | Document gateway need |
| L2 sequencer censorship | Low | L1 forced inclusion |
| Build non-determinism | Med | Pinned images, lockfiles |
| Fresh wallet UX friction | Med | CLI handles rotation |

## Rollback Plan

15-day timelock **is** the rollback window. New proposal reverts CID. Post-update, emergency proposal (high quorum) overwrites.

## Dependencies

L2 testnet, ENS, OZ Contracts v5, Foundry, Docker, Node 20.

## Success Criteria

- [ ] DAO creates proposals, votes, reaches quorum on L2 testnet
- [ ] Timelock enforces 15-day delay before ENS updates
- [ ] Deterministic build produces identical CID across machines
- [ ] Frontend loads via IPFS, displays ENS-resolved CID
- [ ] Non-member verifies deployed CID against proposed CID
