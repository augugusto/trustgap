# ENS Timelock Control Specification

## Purpose

The project's ENS domain SHALL be owned by an OpenZeppelin TimelockController. The DAO (Governor) SHALL be the sole proposer to the timelock. No address other than the timelock SHALL modify the ENS domain.

## Requirements

### Requirement: ENS Ownership

The ENS domain's owner MUST be the TimelockController contract. The resolver MUST point to a public IPFS gateway URL or content hash.

#### Scenario: Timelock controls ENS

- GIVEN the ENS domain registered on L2
- WHEN checking the domain owner
- THEN the owner SHALL be the TimelockController address

#### Scenario: Non-timelock cannot update

- GIVEN an address that is not the TimelockController
- WHEN that address attempts to set the resolver or content hash
- THEN the transaction SHALL revert

### Requirement: Timelock Delay

The timelock SHALL enforce a minimum 15-day delay between a proposal being queued and its execution. An executor role SHALL be held by the TimelockController itself (self-execute).

#### Scenario: Execution before delay ends

- GIVEN a queued timelock operation
- WHEN execute() is called before the delay has elapsed
- THEN the transaction SHALL revert

#### Scenario: Execution after delay

- GIVEN a queued timelock operation
- WHEN the delay has elapsed and execute() is called
- THEN the ENS content hash SHALL be updated atomically

### Requirement: Cancellation

Only the proposer role (Governor) SHALL cancel a pending timelock operation. Cancellation MUST only be possible before execution.

#### Scenario: Cancel before execution

- GIVEN a queued ENS update
- WHEN the Governor calls cancel() before the delay elapses
- THEN the operation SHALL be removed and NOT executed

#### Scenario: Cancel after execution fails

- GIVEN an already executed ENS update
- WHEN any address attempts to cancel it
- THEN the transaction SHALL revert
