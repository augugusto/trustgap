# Trustgap

> Don't trust. Verify.

**Trustgap** is a framework for building applications that close the gap between
what the source code says and what actually runs. It replaces trust with
verification at every layer: from the code repository to the backend execution,
from the DNS name to the static files you receive.

---

## The Trust Gap

When you use open source software today, there are four things you trust but
cannot verify. And one problem that never goes away.

### The Four Gaps

| # | Gap | What you trust | Example |
|---|-----|---------------|---------|
| 1 | **Source → Deploy** | The binary matches the public source | Signal is open source, but how do you know the APK was built from that code? |
| 2 | **DNS → Content** | The domain owner serves the expected version | ProtonMail's frontend is open source, but the domain owner could serve a backdoored version |
| 3 | **Repo → Release** | The repo history hasn't been rewritten | On GitHub, the owner can force-push, delete tags, or inject malicious commits at any time |
| 4 | **Backend → Execution** | The server runs the claimed code | Proton claims their backend is open source, but you can't verify what the server actually runs |

Trustgap closes all four with technology: IPFS, ENS + DAO, Radicle, and smart contracts.

### The Continuous Trust Problem

Even if you verify today's version, you still have to trust that tomorrow's
update won't be malicious. The developer could push a backdoor, the domain
owner could switch the ENS record, the repo could be rewritten overnight.

Trustgap replaces *trust in the developer* with *trust in the process*:

1. Every new version must pass a **DAO vote** (51% quorum, 48h voting period)
2. Approved versions wait in a **15-day public timelock** before going live
3. During those 15 days, **anyone can audit the code** and verify the build
4. If the proposal is malicious, the **EmergencyGovernor** can cancel it with 66% supermajority

You don't need to trust that the developer is honest. You verify that the
process caught them.

### Privacy Layers

Not trust gaps — additional protections for metadata:

| Layer | Recommendation |
|-------|---------------|
| **Dev anonymity** | Submit builds to IPFS through Tor. Radicle supports anonymous contributions. |
| **User anonymity** | Access the frontend through Tor. Static site — no server-side logs. |

Both are recommendations, not built-in enforcement. The user controls their own
privacy.

---

## What Trustgap Does

### Closing the Four Gaps

| Gap | Technology | How |
|-----|-----------|-----|
| **Source → Deploy** | IPFS | Content-addressed, immutable. Same code = same CID. Tampering is detectable at the network layer. |
| **DNS → Content** | ENS + DAO | Human-readable domain. The DAO—not an individual—controls where it points. |
| **Repo → Release** | [Radicle](https://radicle.xyz) | Decentralized git. No single owner. History cannot be rewritten. |
| **Backend → Execution** | Smart contracts | On-chain verified bytecode. The backend IS the contract. No hidden server code. |

### Solving the Update Problem

| Mechanism | How |
|-----------|-----|
| **DAO Governance** | Version approval by collective vote. 51% quorum, 48h voting period. |
| **Timelock** | 15-day mandatory delay between approval and deployment. |
| **EmergencyGovernor** | Cancels malicious proposals. 66% supermajority. Cannot propose — only cancel. |
| **Deterministic Deployment** | Static files + IPFS CID. No build step — what you see is what you deploy. Anyone can reproduce and verify. |

### Privacy (recommendations)

| Layer | How |
|-------|-----|
| **Dev anonymity** | Submit builds to IPFS through Tor. Radicle supports anonymous contributions. |
| **User anonymity** | Access through Tor. Static frontend — no server, no logs. |

---

## Architecture

### Governance Flow

```
  ┌─────────────────────────┐
  │  Radicle (code hosting)  │
  │  Decentralized git       │
  │  No single owner         │
  └───────────┬─────────────┘
              │ propose code change
              ▼
  ┌─────────────────────────┐
  │     Ceremony CLI         │
  │  Docker build → CID      │
  │  Submit to DAO            │
  └───────────┬─────────────┘
              │ propose CID
              ▼
  ┌───────────────────────────────┐
  │         GovernorDAO           │      ┌──────────────────────┐
  │  51% quorum, 48h vote         │      │   DAO Members        │
  │  GovernorTimelockControl      │◄─────│   (1 share each)     │
  └───────────┬───────────────────┘      │   Membership by vote │
              │ schedule                  └──────────────────────┘
              ▼
  ┌───────────────────────────────┐
  │     TimelockController        │◄──── CANCELLER_ROLE ──────┐
  │  15-day minimum delay          │                          │
  │  PROPOSER_ROLE: GovernorDAO    │   ┌──────────────────────┐
  │  EXECUTOR_ROLE: GovernorDAO    │   │  EmergencyGovernor   │
  └───────────┬───────────────────┘   │  66% quorum            │
              │ execute                │  Direct cancellation  │
              ▼                        └──────────────────────┘
  ┌───────────────────────────────┐
  │        ENSResolver             │──→ setContenthash()
  │  Timelock-controlled           │    on ENS Public Resolver
  └───────────┬───────────────────┘
              │ record
              ▼
  ┌───────────────────────────────┐
  │      ReleaseProposal           │
  │  CID recorder (two-phase)      │
  │  RECORDER_ROLE: Timelock       │
  └───────────────────────────────┘
```

### Delivery Flow

```
  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
  │  IPFS peer   │────▶│  ENS resolver │────▶│  Tor circuit  │
  │  (pinned)    │     │  → contenthash│     │  (recommended)│
  └──────────────┘     └──────────────┘     └──────┬───────┘
                                                    │
                      ┌─────────────────────────────┘
                      ▼
              ┌───────────────────────┐
              │   Static Frontend      │
              │  Next.js + ethers.js   │
              │  ┌───────────────────┐ │
              │  │  VerifyBadge       │ │
              │  │  build CID ==     │ │
              │  │  on-chain CID?    │ │
              │  └───────────────────┘ │
              └───────────────────────┘
```

### Smart Contracts

| Contract | Path | Role |
|----------|------|------|
| `DAOShare` | `contracts/src/dao/GovernorDAO.sol` | 1 share = 1 member. Non-transferable (ERC20Votes). New members minted through DAO vote only. |
| `GovernorDAO` | `contracts/src/dao/GovernorDAO.sol` | Main DAO — OZ Governor + TimelockControl. 51% quorum, 48h vote, 15d timelock. |
| `EmergencyGovernor` | `contracts/src/dao/EmergencyGovernor.sol` | 2nd Governor, 66% supermajority quorum, holds CANCELLER_ROLE only. Cannot propose, only cancel. |
| `TimelockController` | OZ standard | 15-day minimum delay. Proposer = GovernorDAO. Executor = anyone (permissionless). |
| `ENSResolver` | `contracts/src/ens/ENSResolver.sol` | Timelock-controlled ENS contenthash wrapper. |
| `ReleaseProposal` | `contracts/src/releases/ReleaseProposal.sol` | Two-phase CID recorder: `recordRelease()` → `markExecuted()`. |

### Packages

| Directory | Package | Tech |
|-----------|---------|------|
| `contracts/` | Solidity + Foundry | OZ Governor v5, forge-std, Solidity 0.8.20 |
| `ceremony/` | TypeScript CLI | commander, @ipld/dag-pb, ethers v6, kubo-rpc-client |
| `frontend/` | Static HTML/CSS/JS | Vanilla JS, ethers.js v5 (vendored), no build step |

---

## The Guarantee

Here's what a user can verify without trusting anyone:

- [ ] **The frontend code matches the approved version.** The page compares its build-time CID against the on-chain `ReleaseProposal` record.
- [ ] **No single person controls the domain.** The ENS domain is owned by the `TimelockController`, which is controlled by the DAO.
- [ ] **Releases had a public audit window.** Every version waited at least 15 days in the timelock before going live.
- [ ] **The backend is verifiable bytecode.** Smart contracts are verified on-chain. There is no hidden server logic.
- [ ] **Membership is by approval.** New members are added through a DAO vote, not self-selection. Every member was explicitly accepted by the existing members.
- [ ] **Votes cannot be bought or accumulated.** 1 member = 1 share. Always. No way to gain more voting power than anyone else.
- [ ] **A malicious release can be stopped.** The `EmergencyGovernor` can cancel pending operations with 66% supermajority.

---

## The DAO is Alive

The DAO is not a tool you control. It is an autonomous entity that exists on the
internet, bound to no jurisdiction. You created it, but you don't own it.

- **It follows its members.** The DAO does what its voters decide, not what its creator wants.
- **It outlives you.** If you disappear tomorrow, the DAO continues operating.
- **It cannot be shut down.** No single server, no legal entity, no point of failure.
- **It provides a real service.** The DAO doesn't just govern a token — it governs a
  working application, from domain resolution to content approval.

This is not a governance experiment. It's a living organism on the internet.

---

## Threat Model

### Verification Threats (the four gaps)

| Threat | Mechanism | Mitigation |
|--------|-----------|------------|
| Frontend tampering | Modified files served to user | IPFS content-addressing. Browser verifies CID against on-chain record. |
| ENS hijack | Domain owner switches contenthash | ENS owned by TimelockController, not an EOA. Only the DAO can update it. |
| GitHub history rewrite | Owner force-pushes or deletes tags | Radicle: decentralized git. History is immutable. No single owner. |
| Backend code mismatch | Server runs different code than claimed | Smart contracts. Verified bytecode on-chain. No hidden server logic. |
| IPFS gateway censorship | ISP blocks gateway | Multiple gateways (dweb.link, cf-ipfs.com, local node). User configurable. |
| Build non-determinism | Different CID across builders | Static files — no build step. Same files = same CID. Sorted directory entries ensure cross-platform reproducibility. |

### Governance Threats (the update problem)

| Threat | Mechanism | Mitigation |
|--------|-----------|------------|
| Malicious proposal | Attacker with enough shares proposes fake content | 48h voting period + 15d timelock = 17-day public audit window |
| Timelock bypass | Attacker executes before delay expires | `TimelockController` enforces minimum delay on-chain |
| DAO takeover (Sybil/vote buying) | Attacker accumulates majority voting power | 1 share per member — voting power cannot be concentrated. Non-transferable tokens prevent buying. 15-day timelock: users detect and abandon before execution. |
| Emergency bypass | Attacker tries to cancel legitimate proposals | EmergencyGovernor requires 66% supermajority |

### Privacy (recommendations, not enforcement)

| Threat | Recommendation |
|--------|---------------|
| Developer metadata exposure | Submit builds to IPFS through Tor. Radicle supports anonymous contributions. |
| User metadata exposure | Access frontend through Tor. Static site — no server-side logs. |

### Emergency Cancellation

If a malicious proposal is detected during the 15-day timelock window:

1. DAO members create an emergency proposal in `EmergencyGovernor`
2. Vote requires **66% supermajority** of all members
3. Passed proposal calls `timelock.cancel(operationId)` directly
4. The pending operation is cancelled — proposer must restart the full cycle

The `EmergencyGovernor` **only** holds `CANCELLER_ROLE` on the `TimelockController`.
It cannot propose new content or bypass the voting process.

---

## Ceremony

The ceremony is a lightweight CLI pipeline that computes the IPFS CID of the
static frontend, verifies it matches the on-chain record, and submits releases
to the DAO.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Static files │────▶│  CLI computes │────▶│  Verify CID  │
│  (no build)  │     │  IPFS CID     │     │  matches     │
└──────────────┘     └──────────────┘     │  on-chain     │
                                           └──────┬───────┘
                                                  │ match
                                           ┌──────▼───────┐
                                           │  Upload to   │
                                           │  IPFS + pin  │
                                           └──────────────┘
```

### Steps

```bash
# 1. Compute IPFS CID of the static frontend (pure JS, no IPFS binary needed)
cd ceremony && pnpm start cid --dir ../frontend

# 2. Verify the CID matches the on-chain record
pnpm start verify --dir ../frontend --expected-cid bafy...

# 3. Submit to DAO (creates a Governor proposal)
pnpm start submit \
  --cid bafy... \
  --resolver 0x... \
  --release-proposal 0x...

# 4. Upload to IPFS
pnpm start ipfs --dir ../frontend --pin
```

> The CID is computed **before** submission so the proposer can verify it
> matches the local build. If it doesn't match the expected value, the
> submission is aborted.

### Determinism

Since the frontend is static HTML/CSS/JS with vendored dependencies, there is
no build step. The same files always produce the same IPFS CID. Determinism is
guaranteed by:

- **Pure-JS CID computation**: no external IPFS binary needed
- **Sorted directory entries**: CID computation sorts files alphabetically for
  cross-platform reproducibility
- **No framework, no build**: what you see in the repo is what gets deployed

---

## Design Decisions

This section explains the why behind key architectural choices.

### Governance

| Decision | Rationale |
|----------|----------|
| **1 share = 1 member** | Every member has exactly 1 share and 1 vote. Voting power cannot be accumulated. No member has more influence than another — it's a council, not a plutocracy. |
| **Membership by DAO vote** | New members are added through a standard governance proposal (vote → timelock → mint). No public `join()`. Every member was explicitly accepted by the existing members, preventing Sybil attacks and membership inflation. |
| **Bootstrap by deployer** | Initial members are minted by the deployer before governance is transferred to the GovernorDAO. The deployer acts once (during deployment) and then loses mint authority. This solves the chicken-and-egg problem of "how does the first member get approved if there's no DAO yet?" |
| **mint/burn through governance** | Both `mint()` and `burn()` require `onlyGovernance` (governor or timelock). This means membership changes flow through the full governance cycle: proposal → vote → timelock → execution. No single person can add or remove members. |
| **Non-transferable tokens** | Shares cannot be transferred between members. `_update()` reverts all non-zero-address transfers. This prevents vote buying, trading, or concentration of voting power through secondary markets. |
| **51% quorum (main DAO)** | A majority of all members must participate for a proposal to pass. With 1 share per member and no inactive ghost members, 51% is both achievable and meaningful. |
| **48h voting period** | 86,400 blocks (~48h at 2s L2 blocks). Gives members a full weekend to detect and vote on proposals. Combined with the 15-day timelock, the security window is approximately 17 days. |
| **EmergencyGovernor: 66% supermajority** | Cancelling a proposal requires broader consensus than passing one. Two-thirds of all members must agree to stop a pending operation. The EmergencyGovernor executes immediately (no timelock) because delay defeats the purpose of emergency cancellation. |
| **EmergencyGovernor: CANCELLER_ROLE only** | The EmergencyGovernor can stop bad things but cannot start new things. It holds no PROPOSER_ROLE or EXECUTOR_ROLE on the timelock. |
| **Permissionless execution** | After the timelock delay, anyone can call `execute()`. No single EOA or bot is required. Execution is decentralized by design. |

### Release Lifecycle

| Decision | Rationale |
|----------|----------|
| **Two-phase release recording** | `recordRelease()` creates a pending entry. `markExecuted()` flips it after timelock execution. The frontend can distinguish "proposed but pending" from "fully executed" releases, with different trust guarantees for each state. |
| **`tx.origin` for proposer attribution** | When called through the `TimelockController`, `tx.origin` preserves the original EOA proposer. `msg.sender` would be the Governor contract. Correct attribution through the call chain. |
| **Raw SHA-256 contenthash** | The ENSResolver stores the contenthash as a raw `bytes32` SHA-256 digest rather than the standard ENS multibase format. This is a simplification for on-chain storage. Standard ENS gateway resolution requires additional conversion. |

### Ceremony & Determinism

| Decision | Rationale |
|----------|----------|
| **No build step** | The frontend is static HTML/CSS/JS with vendored dependencies. There is nothing to build. The files are the deployment. This eliminates an entire class of supply-chain attacks and non-determinism risks. |
| **Pure-JS CID computation** | Uses `@ipld/dag-pb` + `ipfs-unixfs`. No IPFS binary dependency. Works offline. Matches `ipfs add -r --cid-version 1 --raw-leaves` output exactly. |
| **Sorted directory entries** | File system iteration order varies by OS. Without explicit alphabetical sort, the same files would produce different CIDs on Linux vs macOS. |
| **Symlinks skipped** | Symlinks could escape the build output directory or introduce non-determinism. Silently ignored during CID computation. |
| **Upload wraps in directory** | IPFS upload uses `wrapWithDirectory: true`. The CID matches the root directory computation, not individual files. Consistency between CID computation and upload. |

### Frontend

| Decision | Rationale |
|----------|----------|
| **Vanilla HTML/CSS/JS** | No framework, no build step, no dependencies beyond vendored ethers.js. The frontend is self-contained and directly servable from IPFS. |
| **Self-verification against on-chain CID** | The frontend compares its embedded `EXPECTED_CID` against the `ReleaseProposal` contract's latest executed CID. It reads from the chain, not from ENS — the DAO is the source of truth. |
| **Vendored ethers.js** | ethers.js v5 (~760KB) is vendored in the repo. No CDN dependency — the frontend works offline and survives IPFS gateway failures. |
| **Page reload on network change** | `window.location.reload()` on account/network changes. Simplest strategy, 100% reliable for invalidating cached providers and signers. |

### Anonymity

| Decision | Rationale |
|----------|----------|
| **Tor as recommended transport** | Both developers (when submitting builds to IPFS) and users (when accessing the frontend) are encouraged to use Tor. Trustgap does not enforce Tor — the user controls their own privacy. It is an architectural recommendation, not a built-in component. |
| **Radicle for code hosting** | Decentralized git ensures no single entity controls the repository. The template repo lives on GitHub for discoverability, but production deployments should use Radicle. |

---

## Quick Start

```bash
# 1. Install dependencies
pnpm install

# 2. Build contracts
cd contracts && forge install && forge build && cd ..

# 3. Run tests
cd contracts && forge test -vvv && cd ..
cd ceremony && pnpm test && cd ..

# 4. Build ceremony CLI
pnpm --filter ceremony build
```

### Prerequisites

- **Foundry**: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- **pnpm**: `npm install -g pnpm@9`
- **Node.js**: >= 20

---

## Deploy

### Testnet (Base Sepolia)

```bash
# Set up environment
export DEPLOYER_PRIVATE_KEY=0x...
export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
export ENS_PUBLIC_RESOLVER=0x...  # Base Sepolia ENS public resolver
export ENS_NODE=0x...             # keccak256("yourdomain.eth")
export ETHERSCAN_API_KEY=...      # for contract verification

# Deploy all contracts
cd contracts
forge script script/Deploy.s.sol \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

### Post-Deploy

1. Register your ENS domain on Base Sepolia
2. Transfer ENS ownership to the deployed `TimelockController`
3. Run the ceremony to compute the CID and submit the first release
4. Upload the frontend to IPFS
5. Verify via the IPFS gateway

---

## Development

### Running Tests

```bash
# All contracts
cd contracts && forge test -vvv

# Ceremony CLI
cd ceremony && pnpm test

# Single contract test
cd contracts && forge test --match-contract EmergencyGovernor -vvv
```

### Project Structure

```
├── contracts/
│   ├── src/
│   │   ├── dao/GovernorDAO.sol        # DAOShare + Main Governor
│   │   ├── dao/EmergencyGovernor.sol   # Emergency cancellation Governor
│   │   ├── ens/ENSResolver.sol         # ENS contenthash wrapper
│   │   ├── releases/ReleaseProposal.sol # Two-phase CID recorder
│   │   └── lib/Interfaces.sol          # Shared interfaces
│   ├── test/                           # Foundry tests
│   ├── script/Deploy.s.sol             # Deployment script
│   └── foundry.toml
├── ceremony/
│   ├── src/
│   │   ├── index.ts                    # CLI entry (commander)
│   │   ├── cid.ts                      # Pure-JS IPFS CID computation
│   │   ├── verify.ts                   # CID verification (dir vs expected CID)
│   │   ├── submit.ts                   # Proposal calldata builder
│   │   ├── ipfs.ts                     # IPFS upload/pin helpers
│   │   └── logger.ts                   # Structured logging
│   ├── test/                           # Vitest tests
│   └── package.json
├── frontend/
│   ├── index.html                      # Main page with VerifyBadge
│   ├── css/
│   │   └── style.css                   # Styling
│   └── js/
│       ├── vendor/
│       │   └── ethers-5.7.umd.min.js   # Vendored ethers.js (~760KB)
│       ├── config.js                   # EXPECTED_CID, contract addresses
│       ├── contracts.js                # On-chain reads (ReleaseProposal, DAOShare)
│       ├── verify.js                   # CID comparison logic
│       └── app.js                      # Wallet connection + verification flow
├── .github/workflows/ci.yml            # CI pipeline
└── pnpm-workspace.yaml                 # Monorepo config
```

### Adding a Contract

1. Write the contract in `contracts/src/<domain>/`
2. Update `contracts/script/Deploy.s.sol` with deploy + role configuration
3. Write Foundry tests in `contracts/test/`
4. Verify with `forge test --match-contract <ContractName> -vvv`

---

## License

MIT
