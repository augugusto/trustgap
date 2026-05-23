# IPFS Deployment Specification

## Purpose

Publish the deterministic build output to IPFS, produce the CID, and optionally pin the content. The deployment is manual—a member runs the CLI to publish after the build.

## Requirements

### Requirement: IPFS Upload

The ceremony CLI SHALL upload the build output directory to an IPFS node (local or remote). The upload MUST produce the same CID as the local computation.

#### Scenario: Upload matches local CID

- GIVEN a build output directory with a known local CID
- WHEN the CLI uploads it to IPFS
- THEN the IPFS CID SHALL match the locally computed CID

### Requirement: Pinning

The CLI SHOULD pin the content on the IPFS node or request pinning from a pinning service. The system MUST tolerate temporary pinning service unavailability.

#### Scenario: Pinning succeeds

- GIVEN an uploaded directory on IPFS
- WHEN the CLI requests pinning
- THEN the CID SHALL be pinned and remain available

#### Scenario: Pinning service unavailable

- GIVEN an IPFS node that is reachable but a pinning service that is not
- WHEN the CLI attempts to pin
- THEN the upload SHALL still succeed and the CLI SHALL warn about missing pin

### Requirement: CID Verification

The frontend SHALL resolve the ENS domain to its content hash and compare it against the gateway-served content's CID. A mismatch SHALL be displayed to the user.

#### Scenario: CID matches on-chain

- GIVEN a frontend page loaded via IPFS gateway
- WHEN the page reads the ENS content hash
- THEN it SHALL display "Verified: CID matches on-chain" if they match

#### Scenario: CID mismatch alert

- GIVEN a frontend page loaded via IPFS gateway
- WHEN the ENS content hash differs from the page's actual CID
- THEN the page SHALL display a warning banner
