// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../lib/Interfaces.sol";

/// @title ReleaseProposal
/// @notice Records and tracks release proposals on-chain.
///         Each release proposal stores the target CID, proposer, and execution status.
///         The TimelockController is granted RECORDER_ROLE and calls recordRelease()
///         as part of the proposal execution flow (Governor → Timelock → ENS update).
contract ReleaseProposal is AccessControl, IReleaseRecorder {
    /// @notice Role allowed to record releases (granted to TimelockController)
    bytes32 public constant RECORDER_ROLE = keccak256("RECORDER_ROLE");

    /// @notice Structure representing a recorded release
    struct Release {
        bytes32 cid;
        address proposer;
        uint256 timestamp;
        bool executed;
    }

    /// @notice Array of all release records
    Release[] private _releases;

    /// @notice Reverts if CID is zero
    error ZeroCID();

    /// @notice Constructor: grants admin and recorder roles to deployer
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RECORDER_ROLE, msg.sender);
    }

    /// @inheritdoc IReleaseRecorder
    function recordRelease(bytes32 cid) external onlyRole(RECORDER_ROLE) returns (uint256 index) {
        if (cid == bytes32(0)) revert ZeroCID();
        index = _releases.length;
        _releases.push(Release({
            cid: cid,
            proposer: tx.origin,
            timestamp: block.timestamp,
            executed: false
        }));
        emit ReleaseRecorded(index, cid);
    }

    /// @notice Mark a release as executed after the Timelock delay has elapsed.
    ///         Only callable by RECORDER_ROLE (the TimelockController).
    /// @param index The index of the release to mark as executed
    function markExecuted(uint256 index) external onlyRole(RECORDER_ROLE) {
        require(index < _releases.length, "ReleaseProposal: invalid index");
        Release storage r = _releases[index];
        require(!r.executed, "ReleaseProposal: already executed");
        r.executed = true;
        r.timestamp = block.timestamp;
    }

    /// @inheritdoc IReleaseRecorder
    function getReleaseCount() external view returns (uint256) {
        return _releases.length;
    }

    /// @inheritdoc IReleaseRecorder
    function getReleaseCID(uint256 index) external view returns (bytes32 cid) {
        require(index < _releases.length, "ReleaseProposal: invalid index");
        return _releases[index].cid;
    }

    /// @notice Get full release details
    /// @param index The release index
    /// @return cid The IPFS CID
    /// @return proposer The address that proposed the release
    /// @return timestamp When the release was recorded (or executed)
    /// @return executed Whether the release was executed
    function getRelease(
        uint256 index
    ) external view returns (bytes32 cid, address proposer, uint256 timestamp, bool executed) {
        require(index < _releases.length, "ReleaseProposal: invalid index");
        Release storage r = _releases[index];
        return (r.cid, r.proposer, r.timestamp, r.executed);
    }
}
