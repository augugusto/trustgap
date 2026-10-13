// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

// ----------------------------------------------------------------------------
// EmergencyGovernor — Cancellation-only Governor with 66% supermajority quorum
// ----------------------------------------------------------------------------

/// @title EmergencyGovernor
/// @notice Governor with 66% quorum that holds CANCELLER_ROLE on the main
///         DAO's TimelockController. Used for emergency cancellation of pending
///         malicious proposals through a governance vote. The supermajority
///         requirement ensures broad consensus for emergency actions.
///
/// Critical difference from GovernorDAO: EmergencyGovernor does NOT use
/// GovernorTimelockControl — its proposals execute directly without going
/// through the timelock. This allows execution targets like timelock.cancel()
/// to be called as direct external calls. The deployer grants only
/// CANCELLER_ROLE to this contract on the TimelockController, preventing it
/// from scheduling new content proposals while still reacting to emergencies.
///
/// Key parameters (1 share = 1 member):
///   - votingDelay:      1 block  (same as main Governor)
///   - votingPeriod:     86400 blocks (~48 hours, same as main Governor)
///   - proposalThreshold: 1e18    (1 share — any member can propose)
///   - quorum:           66% of total members (supermajority)
contract EmergencyGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction
{
    /// @notice The main DAO's TimelockController
    TimelockController public immutable timelock;

    /// @notice Thrown when an emergency execution target call fails
    error EmergencyExecutionFailed(uint256 index);

    /// @notice Constructs the EmergencyGovernor
    /// @param _token The DAOShare voting token contract
    /// @param _timelock The main TimelockController contract
    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("EmergencyGovernor")
        GovernorSettings(
            1,       // votingDelay: 1 block
            86400,   // votingPeriod: ~48h at 2s L2 blocks
            1e18     // proposalThreshold: 1 share minimum
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(66) // 66% quorum — supermajority
    {
        timelock = _timelock;
    }

    // ──────────────────────────────────────────────────────────
    //  GovernorSettings overrides (required by Solidity diamond)
    // ──────────────────────────────────────────────────────────

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    // ──────────────────────────────────────────────────────────
    //  GovernorVotesQuorumFraction + GovernorCountingSimple
    // ──────────────────────────────────────────────────────────

    function quorum(
        uint256 blockNumber
    ) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function _quorumReached(
        uint256 proposalId
    ) internal view override(Governor, GovernorCountingSimple) returns (bool) {
        return super._quorumReached(proposalId);
    }

    function _voteSucceeded(
        uint256 proposalId
    ) internal view override(Governor, GovernorCountingSimple) returns (bool) {
        return super._voteSucceeded(proposalId);
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) internal override(Governor, GovernorCountingSimple) {
        super._countVote(proposalId, account, support, weight, params);
    }

    // ──────────────────────────────────────────────────────────
    //  Governor (no GovernorTimelockControl — direct execution)
    // ──────────────────────────────────────────────────────────

    /// @notice Executes operations directly via external call.
    ///         Override exists purely to provide a clearer revert message
    ///         in case of execution failure.
    function _executeOperations(
        uint256 /*proposalId*/,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 /*descriptionHash*/
    ) internal override(Governor) {
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, ) = targets[i].call{value: values[i]}(calldatas[i]);
            if (!success) revert EmergencyExecutionFailed(i);
        }
    }

    function _executor()
        internal
        view
        override(Governor)
        returns (address)
    {
        return address(this);
    }
}
