# Frontend Base Specification

## Purpose

A static Next.js application that connects to L2 via ethers.js, reads the ENS content hash, and verifies it against the IPFS-served content. The frontend is static-exported and served via IPFS. End users never touch the blockchain directly—read-only contract reads via ethers.js.

## Requirements

### Requirement: Static Export

The Next.js app MUST support `next export` (or `output: export`) producing a fully static directory with no server runtime. The build SHALL produce an `out/` directory suitable for IPFS upload.

#### Scenario: Static export succeeds

- GIVEN a Next.js project with static export configuration
- WHEN `next build && next export` runs
- THEN an `out/` directory SHALL be produced with no server dependencies

### Requirement: Wallet Connect

The app SHALL provide a "Connect Wallet" button using ethers.js v6 and BrowserProvider. The user MUST be able to connect any EIP-1193 wallet (MetaMask, WalletConnect, etc.).

#### Scenario: Wallet connects successfully

- GIVEN a user with a browser wallet installed
- WHEN they click "Connect Wallet"
- THEN the app SHALL display the connected address

#### Scenario: No wallet installed

- GIVEN a browser without an EIP-1193 wallet
- WHEN the page loads
- THEN the app SHALL display "No wallet detected" with a link to install

### Requirement: Read ENS Content Hash

The app SHALL read the ENS content hash from the L2 chain using ethers.js. The app SHALL NOT write transactions—read-only.

#### Scenario: Content hash resolved

- GIVEN a connected wallet on the correct L2
- WHEN the app calls ENS resolver's text() or contenthash()
- THEN the content hash SHALL be displayed on screen

#### Scenario: Network mismatch

- GIVEN a connected wallet on the wrong network
- WHEN the app attempts to read ENS
- THEN the app SHALL display "Wrong network" and prompt to switch

### Requirement: CID Verification Display

The app SHALL compare the ENS-resolved CID against the CID of the page itself (as served by IPFS). A visual indicator SHALL show verified or unverified status.

#### Scenario: Verified deployment

- GIVEN the app loaded via IPFS gateway
- WHEN the ENS CID matches the page-served CID
- THEN a green "Verified" badge SHALL be displayed

#### Scenario: Unverified deployment

- GIVEN the app loaded via IPFS gateway
- WHEN the ENS CID does NOT match the page-served CID
- THEN a red "Unverified" badge SHALL be displayed
