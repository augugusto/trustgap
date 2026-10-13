// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import "../src/releases/ReleaseProposal.sol";
import "../src/lib/Interfaces.sol";

contract ReleaseProposalTest is Test {
    ReleaseProposal public recorder;

    bytes32 public constant CID_1 = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;
    bytes32 public constant CID_2 = 0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb;

    address public recorder_role = address(0x1);
    address public attacker = address(0x2);

    event ReleaseRecorded(uint256 indexed index, bytes32 indexed cid);

    function setUp() public {
        recorder = new ReleaseProposal();

        // Grant RECORDER_ROLE to test caller
        recorder.grantRole(recorder.RECORDER_ROLE(), recorder_role);

        // Revoke RECORDER_ROLE from deployer (this contract)
        recorder.revokeRole(recorder.RECORDER_ROLE(), address(this));
    }

    // ── Constructor ─────────────────────────────────────────────────

    function test_Constructor_GrantsDeployerAdmin() public view {
        assertTrue(recorder.hasRole(recorder.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    function test_Constructor_InitialCountZero() public view {
        assertEq(recorder.getReleaseCount(), 0);
    }

    // ── recordRelease ───────────────────────────────────────────────

    function test_RecordRelease_EmitsEvent() public {
        vm.prank(recorder_role);
        vm.expectEmit(true, true, true, true, address(recorder));
        emit ReleaseRecorded(0, CID_1);
        recorder.recordRelease(CID_1);
    }

    function test_RecordRelease_IncrementsCount() public {
        vm.startPrank(recorder_role);
        recorder.recordRelease(CID_1);
        recorder.recordRelease(CID_2);
        vm.stopPrank();

        assertEq(recorder.getReleaseCount(), 2);
    }

    function test_RecordRelease_StoresCID() public {
        vm.prank(recorder_role);
        recorder.recordRelease(CID_1);

        (bytes32 cid, , , bool executed) = recorder.getRelease(0);
        assertEq(cid, CID_1);
        assertFalse(executed);
    }

    function test_RecordRelease_StoresProposer() public {
        // The contract records tx.origin, so set both msg.sender and tx.origin
        vm.prank(recorder_role, recorder_role);
        recorder.recordRelease(CID_1);

        (, address proposer, , ) = recorder.getRelease(0);
        assertEq(proposer, recorder_role);
    }

    function test_RecordRelease_ZeroCID_Reverts() public {
        vm.expectRevert(ReleaseProposal.ZeroCID.selector);
        vm.prank(recorder_role);
        recorder.recordRelease(bytes32(0));
    }

    // ── Role Enforcement ────────────────────────────────────────────

    function test_NonRecorderCannotRecord() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                recorder.RECORDER_ROLE()
            )
        );
        vm.prank(attacker);
        recorder.recordRelease(CID_1);
    }

    function test_NonRecorderCannotMarkExecuted() public {
        vm.prank(recorder_role);
        recorder.recordRelease(CID_1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                recorder.RECORDER_ROLE()
            )
        );
        vm.prank(attacker);
        recorder.markExecuted(0);
    }

    // ── markExecuted ────────────────────────────────────────────────

    function test_MarkExecuted() public {
        vm.startPrank(recorder_role);
        uint256 idx = recorder.recordRelease(CID_1);
        recorder.markExecuted(idx);
        vm.stopPrank();

        (, , uint256 timestamp, bool executed) = recorder.getRelease(0);
        assertTrue(executed);
        assertGt(timestamp, 0);
    }

    function test_MarkExecuted_InvalidIndex_Reverts() public {
        vm.expectRevert("ReleaseProposal: invalid index");
        vm.prank(recorder_role);
        recorder.markExecuted(0);
    }

    function test_MarkExecuted_DoubleExecution_Reverts() public {
        vm.startPrank(recorder_role);
        uint256 idx = recorder.recordRelease(CID_1);
        recorder.markExecuted(idx);
        vm.expectRevert("ReleaseProposal: already executed");
        recorder.markExecuted(idx);
        vm.stopPrank();
    }

    // ── getReleaseCID ────────────────────────────────────────────────

    function test_GetReleaseCID_ReturnsCID() public {
        vm.prank(recorder_role);
        recorder.recordRelease(CID_2);
        assertEq(recorder.getReleaseCID(0), CID_2);
    }

    function test_GetReleaseCID_InvalidIndex_Reverts() public {
        vm.expectRevert("ReleaseProposal: invalid index");
        recorder.getReleaseCID(0);
    }

    function test_GetRelease_InvalidIndex_Reverts() public {
        vm.expectRevert("ReleaseProposal: invalid index");
        recorder.getRelease(0);
    }
}
