# Release Proposal Specification

## Purpose

A dedicated proposal type that encodes an IPFS CID target for the ENS content hash. Flow: propose CID → DAO vote → 15d timelock → auto-execute ENS update.

## Requirements

### Requirement: Propose CID

A member SHALL submit a release proposal containing an IPFS CID (bytes32). The proposal MUST reference the ENS setContentHash operation via the timelock.

#### Scenario: Valid CID proposal

- GIVEN a member with voting weight
- WHEN they submit a proposal with an IPFS CID
- THEN a ReleaseProposal SHALL be created referencing the target CID

#### Scenario: Zero-address CID rejected

- GIVEN any member
- WHEN they submit a proposal with a zero bytes32 CID
- THEN the transaction SHALL revert

### Requirement: Auto-Execute

A successful proposal SHALL, after the timelock delay, automatically call ENS setContentHash with the proposed CID. The ReleaseProposal contract SHALL encode this as the timelock target.

#### Scenario: Successful vote triggers ENS update

- GIVEN a release proposal that passed governance and was queued
- WHEN the timelock delay elapses and execute() is called
- THEN the ENS content hash SHALL equal the proposed CID

### Requirement: Rollback via New Proposal

A new release proposal with a different CID SHALL replace the current ENS content hash after following the full vote + timelock cycle.

#### Scenario: Rollback proposal

- GIVEN a deployed CID on ENS
- WHEN a new release proposal for a different CID passes and executes
- THEN the ENS content hash SHALL be updated to the new CID

### Requirement: Emergency Overwrite

A governance proposal with elevated quorum (e.g., 2x normal) SHALL be able to overwrite the ENS hash without the full 15-day delay. This MUST be a separate proposal type with clear on-chain distinction.

#### Scenario: Emergency CID update

- GIVEN a compromised deployment
- WHEN an emergency proposal with elevated quorum passes and executes
- THEN the ENS content hash SHALL be updated immediately
