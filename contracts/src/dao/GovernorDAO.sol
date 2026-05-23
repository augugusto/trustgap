// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// ----------------------------------------------------------------------------
// DAOShare — 1 share = 1 member, non-transferable, mint-only-through-governance
// ----------------------------------------------------------------------------

/// @title DAOShare
/// @notice One member = exactly 1 share. Membership is granted exclusively
///         through a DAO proposal that passes the standard governance cycle
///         (vote → timelock → execution). No public join function exists.
///         New members must be approved by existing members.
///
///         Shares are non-transferable and carry 1 vote each via ERC20Votes.
///         Both mint() and burn() are restricted to governor or timelock,
///         enabling membership proposals to flow through the full governance cycle.
contract DAOShare is ERC20Votes {
    /// @notice Address of the GovernorDAO contract authorized to manage members
    address public governor;

    /// @notice Address of the TimelockController — also authorized because
    ///         governance proposals execute through the timelock
    address public timelock;

    /// @notice Emitted when the governor address changes
    event GovernorSet(address indexed governor);

    /// @notice Emitted when the timelock address changes
    event TimelockSet(address indexed timelock);

    /// @notice Thrown when mint is called for an existing member
    error AlreadyMember();

    /// @notice Thrown when burn is called for a non-member
    error NotMember();

    /// @notice Restricts functions to governor or timelock
    modifier onlyGovernance() {
        require(
            msg.sender == governor || msg.sender == timelock,
            "DAOShare: not authorized"
        );
        _;
    }

    /// @notice Constructs the DAOShare token.
    ///         Deployer is set as initial governor for bootstrap.
    constructor() ERC20("Trustgap DAO", "TGAP") ERC20Permit("Trustgap DAO") {
        governor = msg.sender;
    }

    /// @notice Sets the governor address
    /// @param _governor The new governor address
    function setGovernor(address _governor) external {
        require(msg.sender == governor, "DAOShare: only governor");
        require(_governor != address(0), "DAOShare: zero address");
        governor = _governor;
        emit GovernorSet(_governor);
    }

    /// @notice Sets the timelock address authorized alongside the governor
    /// @param _timelock The TimelockController address
    function setTimelock(address _timelock) external {
        require(msg.sender == governor, "DAOShare: only governor");
        require(_timelock != address(0), "DAOShare: zero address");
        timelock = _timelock;
        emit TimelockSet(_timelock);
    }

    /// @notice Mint exactly 1 share to a new member.
    ///         Callable only through governance (governor or timelock).
    /// @param to The address receiving membership
    function mint(address to) external onlyGovernance {
        if (balanceOf(to) > 0) revert AlreadyMember();
        _mint(to, 1);
    }

    /// @notice Burn 1 share from a member, revoking their membership.
    ///         Callable only through governance.
    /// @param from The address whose membership is revoked
    function burn(address from) external onlyGovernance {
        if (balanceOf(from) == 0) revert NotMember();
        _burn(from, 1);
    }

    /// @notice Hook override to make shares non-transferable.
    ///         Mints (from == address(0)) and burns (to == address(0)) are allowed.
    ///         All other transfers revert.
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        if (from != address(0) && to != address(0)) {
            revert("DAOShare: non-transferable");
        }
        super._update(from, to, amount);
    }

    /// @dev Override required by Solidity for ERC20Permit ↔ ERC20Votes diamond
    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}

// ----------------------------------------------------------------------------
// GovernorDAO — OZ Governor with TimelockControl, 51% quorum
// ----------------------------------------------------------------------------

/// @title GovernorDAO
/// @notice OpenZeppelin Governor contract with timelock control for Trustgap.
///         Members hold non-transferable shares (DAOShare) — exactly 1 per member.
///         Proposals require 51% quorum and flow through a 15-day timelock.
///
/// Key parameters:
///   - votingDelay:      1 block
///   - votingPeriod:     86400 blocks (~48 hours at 2s L2 blocks)
///   - proposalThreshold: 1e18 (1 share — any member can propose)
///   - quorum:           51% of total members
contract GovernorDAO is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /// @notice Constructs the GovernorDAO
    /// @param _token The DAOShare voting token contract
    /// @param _timelock The TimelockController contract
    constructor(
        IVotes _token,
        TimelockController _timelock
    )
        Governor("GovernorDAO")
        GovernorSettings(
            1,       // votingDelay: 1 block
            86400,   // votingPeriod: ~48h at 2s L2 blocks
            1e18     // proposalThreshold: 1 share minimum
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(51) // 51% quorum — majority of members
        GovernorTimelockControl(_timelock)
    {}

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
    ) internal view override(Governor, GovernorVotesQuorumFraction) returns (bool) {
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
    //  GovernorTimelockControl overrides
    // ──────────────────────────────────────────────────────────

    function state(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return
            super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
}
