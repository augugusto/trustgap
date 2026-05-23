# DAO Governance Specification

## Purpose

On-chain DAO using OpenZeppelin Governor for membership, proposal creation, voting, and timelock scheduling. Members hold shares; anyone may join; members may be removed by vote.

## Requirements

### Requirement: Membership

A person SHALL join the DAO by acquiring shares via a designated join function. Shares MUST be non-transferable and represent voting weight. Membership MUST be revocable by a governance vote.

#### Scenario: Anyone joins with shares

- GIVEN a new wallet address with no shares
- WHEN the wallet calls the join function with a minimum share contribution
- THEN the wallet SHALL be recorded as a member with voting weight equal to shares held

#### Scenario: Non-member cannot vote

- GIVEN an address with zero shares
- WHEN that address submits a vote
- THEN the transaction SHALL revert

### Requirement: Voting

The DAO SHALL use OpenZeppelin Governor with shares-based weighting. A proposal SHALL require a minimum quorum of shares to pass. Voting period MUST be at least 48 hours on L2.

#### Scenario: Quorum not met

- GIVEN a proposal in voting period
- WHEN the period ends with votes below quorum threshold
- THEN the proposal SHALL be defeated

#### Scenario: Quorum met, majority approves

- GIVEN a proposal in voting period
- WHEN votes cast exceed quorum and majority supports
- THEN the proposal SHALL succeed and enter queue

### Requirement: Member Removal

A governance proposal MAY remove a member by burning their shares. Removed members MUST lose all voting weight immediately upon execution.

#### Scenario: Member removed loses voting power

- GIVEN a governance proposal to remove a member passes and executes
- WHEN that member subsequently attempts to vote
- THEN the vote SHALL be rejected

### Requirement: Anyone Can Propose

Any member SHALL be able to create a proposal. A minimum share threshold MAY be required to prevent spam.

#### Scenario: Member creates proposal

- GIVEN a member with sufficient shares
- WHEN they call propose() with valid calldata
- THEN a new proposal SHALL be created in Pending state
