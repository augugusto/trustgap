// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/dao/GovernorDAO.sol";

// Mock target contract for proposal execution testing
contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }
}

contract DAOGovernorTest is Test {
    DAOShare public share;
    TimelockController public timelock;
    GovernorDAO public governor;
    MockTarget public target;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public david = makeAddr("david");

    uint256 public constant QUORUM_PERCENT = 51;

    // ── Setup ───────────────────────────────────────────────────────

    function setUp() public {
        _deployContracts(0);
        _setupMembers();
        _setupTarget();
    }

    function _deployContracts(uint256 timelockDelay) internal {
        // Foundry starts at block.timestamp == 1, which collides with the
        // TimelockController's _DONE_TIMESTAMP sentinel: a zero-delay schedule
        // would look already executed. Move off t=1 first.
        vm.warp(block.timestamp + 1);

        vm.startPrank(address(this));

        // 1. DAOShare (deployer = governor for bootstrap)
        share = new DAOShare();

        // 2. TimelockController — zero delay for most tests
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute after delay
        timelock = new TimelockController(timelockDelay, proposers, executors, address(this));

        // 3. GovernorDAO (51% quorum)
        governor = new GovernorDAO(IVotes(address(share)), timelock);

        // 4. Configure Timelock: Governor = proposer + executor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), address(this));

        // 5. Bootstrap: deployer mints initial members before transferring governance
        share.mint(alice);
        share.mint(bob);

        // 6. Configure DAOShare governance
        share.setTimelock(address(timelock));
        share.setGovernor(address(governor));

        vm.stopPrank();
    }

    function _setupMembers() internal {
        // Each member delegates to themselves: 1 share = 1e18 voting units
        vm.prank(alice);
        share.delegate(alice);

        vm.prank(bob);
        share.delegate(bob);

        // Votes only show up in past checkpoints, so advance one block before
        // the Governor reads getVotes(proposer, clock() - 1).
        vm.roll(block.number + 1);
    }

    function _setupTarget() internal {
        target = new MockTarget();
    }

    // ── Helpers ─────────────────────────────────────────────────────

    function _createProposal(
        address targetAddr,
        bytes memory callData,
        string memory description
    ) internal returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = targetAddr;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        vm.prank(alice);
        return governor.propose(targets, values, calldatas, description);
    }

    function _createAndVoteProposal(
        address targetAddr,
        bytes memory callData,
        string memory description,
        uint8 aliceVote,
        uint8 bobVote
    ) internal returns (uint256) {
        uint256 proposalId = _createProposal(targetAddr, callData, description);

        // Advance past voting delay
        vm.roll(block.number + governor.votingDelay() + 1);

        // Vote
        if (aliceVote <= 2) {
            vm.prank(alice);
            governor.castVote(proposalId, aliceVote);
        }
        if (bobVote <= 2) {
            vm.prank(bob);
            governor.castVote(proposalId, bobVote);
        }

        // Advance to end of voting period
        vm.roll(block.number + governor.votingPeriod());

        return proposalId;
    }

    function _queueProposal(
        address targetAddr,
        bytes memory callData,
        string memory description
    ) internal {
        address[] memory targets = new address[](1);
        targets[0] = targetAddr;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        governor.queue(targets, values, calldatas, keccak256(bytes(description)));
    }

    function _executeProposal(
        address targetAddr,
        bytes memory callData,
        string memory description
    ) internal {
        address[] memory targets = new address[](1);
        targets[0] = targetAddr;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        governor.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    // ── 1. Membership Tests ─────────────────────────────────────────

    function test_Membership_OneShareEach() public {
        assertEq(share.balanceOf(alice), 1e18);
        assertEq(share.balanceOf(bob), 1e18);
        assertEq(share.totalSupply(), 2e18);
    }

    function test_Membership_DelegateGrantsVotingPower() public {
        assertEq(share.getVotes(alice), 1e18);
        assertEq(share.getVotes(bob), 1e18);
    }

    function test_Membership_NonTransferable() public {
        vm.expectRevert("DAOShare: non-transferable");
        vm.prank(alice);
        share.transfer(bob, 1);
    }

    function test_Membership_CannotJoinPublicly() public {
        // No public join() exists — the function was removed.
        // Charlie cannot mint shares to themselves.
        // The mint() function requires onlyGovernance (governor or timelock).
        vm.expectRevert("DAOShare: not authorized");
        vm.prank(charlie);
        share.mint(charlie);
    }

    function test_Membership_CannotMintTwice() public {
        // Only governor/timelock can mint, and only to non-members.
        // Since governance was already transferred to GovernorDAO,
        // this reverts for non-governance callers.
        vm.expectRevert("DAOShare: not authorized");
        share.mint(alice);
    }

    // ── 2. Proposal Creation Tests ──────────────────────────────────

    function test_MemberCanCreateProposal() public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);
        uint256 proposalId = _createProposal(address(target), data, "Set value to 42");

        assertGt(proposalId, 0);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
    }

    function test_NonMemberCannotPropose() public {
        // Charlie is not a member (0 shares)
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernor.GovernorInsufficientProposerVotes.selector,
                charlie,
                0,
                1e18
            )
        );
        vm.prank(charlie);
        governor.propose(targets, values, calldatas, "Charlie's proposal");
    }

    // ── 3. Voting Tests ─────────────────────────────────────────────

    function test_FullVoteFlow_Executes() public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);
        // Both alice and bob vote For → 2 votes, quorum 51% of 2 = 1.02 → need 2
        uint256 proposalId = _createAndVoteProposal(
            address(target),
            data,
            "Set value to 42",
            1, // Alice For
            1 // Bob For
        );

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Queue
        _queueProposal(address(target), data, "Set value to 42");
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // Execute (timelock delay = 0)
        _executeProposal(address(target), data, "Set value to 42");
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));

        // Verify the target was called
        assertEq(target.getValue(), 42);
    }

    function test_QuorumNotMet_WithOneVote_Defeated() public {
        // 2 members (2e18 supply) -> quorum = 51% = 1.02e18.
        // Only alice votes For with 1e18, so quorum is not reached.
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);
        uint256 proposalId = _createAndVoteProposal(
            address(target), data, "Only alice votes", 1, 3
        );

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
        assertEq(target.getValue(), 0);
    }

    function test_NonMemberCannotVote() public {
        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 42);
        uint256 proposalId = _createProposal(address(target), data, "Charlie votes");

        vm.roll(block.number + governor.votingDelay() + 1);

        // OZ v5 does not revert on zero weight: the vote is recorded with
        // weight 0, so it must not move any of the tallies.
        vm.prank(charlie);
        governor.castVote(proposalId, 1);

        (, uint256 forVotes, ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, 0);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
    }

    // ── 4. Member Addition (through governance) ─────────────────────

    function test_AddMember_ViaGovernance() public {
        // Propose adding charlie as a member
        bytes memory data = abi.encodeWithSignature("mint(address)", charlie);
        string memory description = "Add charlie as member";

        uint256 proposalId = _createAndVoteProposal(
            address(share),
            data,
            description,
            1, // Alice For
            1 // Bob For
        );

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        _queueProposal(address(share), data, description);
        _executeProposal(address(share), data, description);

        assertEq(share.balanceOf(charlie), 1e18);
        assertEq(share.totalSupply(), 3e18);
    }

    function test_AddMember_MustBeApproved() public {
        // Propose adding charlie, but only alice votes For, bob votes Against
        bytes memory data = abi.encodeWithSignature("mint(address)", charlie);
        string memory description = "Add charlie";
        uint256 proposalId = _createAndVoteProposal(
            address(share),
            data,
            description,
            1, // Alice For
            0 // Bob Against
        );

        // 1 For vs 1 Against, total votes = 2
        // quorum = 2*51/100 = 1 → quorum met (2 votes cast).
        // voteSucceeded: For > Against? 1 > 1 = false → Defeated
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
        assertEq(share.balanceOf(charlie), 0);
    }

    function test_MemberAddition_CannotMintAlreadyMember() public {
        // Try to mint to alice (already a member). Should revert in execution.
        bytes memory data = abi.encodeWithSignature("mint(address)", alice);
        string memory description = "Add alice again";

        uint256 proposalId = _createAndVoteProposal(
            address(share),
            data,
            description,
            1, // Alice For
            1 // Bob For
        );

        _queueProposal(address(share), data, description);

        // Execution should revert because alice is already a member
        vm.expectRevert(DAOShare.AlreadyMember.selector);
        _executeProposal(address(share), data, description);
    }

    // ── 5. Member Removal ───────────────────────────────────────────

    function test_RemoveMember_ViaGovernance() public {
        // Add charlie first so a majority (alice + charlie) can outvote bob.
        bytes memory addData = abi.encodeWithSignature("mint(address)", charlie);
        string memory addDesc = "Add charlie";
        _createAndVoteProposal(address(share), addData, addDesc, 1, 1);
        _queueProposal(address(share), addData, addDesc);
        _executeProposal(address(share), addData, addDesc);
        assertEq(share.balanceOf(charlie), 1e18);

        vm.prank(charlie);
        share.delegate(charlie);
        vm.roll(block.number + 1);

        bytes memory data = abi.encodeWithSignature("burn(address)", bob);
        string memory description = "Remove bob";

        address[] memory targets = new address[](1);
        targets[0] = address(share);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        vm.prank(alice);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(alice);
        governor.castVote(proposalId, 1);
        vm.prank(charlie);
        governor.castVote(proposalId, 1);
        vm.prank(bob);
        governor.castVote(proposalId, 0);

        vm.roll(block.number + governor.votingPeriod());

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        _queueProposal(address(share), data, description);
        _executeProposal(address(share), data, description);

        assertEq(share.balanceOf(bob), 0);
        assertEq(share.getVotes(bob), 0);
        assertEq(share.totalSupply(), 2e18);
    }

    // ── 6. Timelock Delay Enforcement ───────────────────────────────

    function test_TimelockDelay_Enforced() public {
        // Redeploy with non-zero delay
        _deployContracts(7 days);
        _setupMembers();
        _setupTarget();

        bytes memory data = abi.encodeWithSignature("setValue(uint256)", 99);
        uint256 proposalId = _createAndVoteProposal(
            address(target),
            data,
            "Delayed execution",
            1, // Alice For
            1 // Bob For
        );

        // Queue succeeds
        _queueProposal(address(target), data, "Delayed execution");
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // Attempt execute before delay -> reverts (operation not ready yet)
        vm.expectRevert();
        _executeProposal(address(target), data, "Delayed execution");

        // Fast forward past delay
        vm.warp(block.timestamp + 7 days + 1);

        // Execute succeeds
        _executeProposal(address(target), data, "Delayed execution");
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        assertEq(target.getValue(), 99);
    }

    // ── 7. Quorum Calculation ───────────────────────────────────────

    function test_QuorumCalculation() public {
        // 51% of 2 members (2e18 supply) = 1.02e18
        uint256 expectedQuorum = (2e18 * QUORUM_PERCENT) / 100;
        assertEq(governor.quorum(block.number - 1), expectedQuorum);
    }

    function test_QuorumIncreasesWithMembers() public {
        uint256 quorumWith2 = governor.quorum(block.number - 1);

        // Add david through the full governance flow
        bytes memory data = abi.encodeWithSignature("mint(address)", david);
        string memory desc = "Add david";
        _createAndVoteProposal(address(share), data, desc, 1, 1);
        _queueProposal(address(share), data, desc);
        _executeProposal(address(share), data, desc);

        assertEq(share.balanceOf(david), 1e18);
        assertEq(share.totalSupply(), 3e18);

        // Advance a few blocks so the new supply is settled as a past checkpoint
        vm.roll(block.number + 10);
        uint256 quorumWith3 = governor.quorum(block.number - 5);

        assertEq(quorumWith2, (2e18 * QUORUM_PERCENT) / 100);
        assertEq(quorumWith3, (3e18 * QUORUM_PERCENT) / 100);
        assertGt(quorumWith3, quorumWith2);
    }
}
