// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ens/ENSResolver.sol";
import "../src/lib/Interfaces.sol";

// Mock ENS public resolver for testing
contract MockENSPublicResolver is IENSPublicResolver {
    mapping(bytes32 => bytes) private _hashes;

    function setContenthash(bytes32 node, bytes32 hash) external {
        _hashes[node] = abi.encodePacked(hash);
    }

    function contenthash(bytes32 node) external view returns (bytes memory) {
        return _hashes[node];
    }
}

contract ENSResolverTest is Test {
    ENSResolver public resolver;
    MockENSPublicResolver public mockPublicResolver;

    bytes32 public constant TEST_NODE = keccak256("test.eth");
    bytes32 public constant TEST_CID = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    address public caller = address(0x1);
    address public attacker = address(0x2);

    event ContenthashSet(bytes32 indexed contenthash);

    function setUp() public {
        mockPublicResolver = new MockENSPublicResolver();

        // Deploy ENSResolver with deployer (this contract) as admin + caller
        resolver = new ENSResolver(address(mockPublicResolver), TEST_NODE);

        // Grant CALLER_ROLE to test caller
        resolver.grantRole(resolver.CALLER_ROLE(), caller);

        // Revoke CALLER_ROLE from deployer (this contract) for clean permissions
        resolver.revokeRole(resolver.CALLER_ROLE(), address(this));
    }

    // ── Constructor ─────────────────────────────────────────────────

    function test_Constructor_SetsENSNode() public view {
        assertEq(resolver.ensNode(), TEST_NODE);
    }

    function test_Constructor_SetsPublicResolver() public view {
        assertEq(address(resolver.publicResolver()), address(mockPublicResolver));
    }

    function test_Constructor_GrantsDeployerAdmin() public view {
        assertTrue(resolver.hasRole(resolver.DEFAULT_ADMIN_ROLE(), address(this)));
    }

    // ── setContenthash ──────────────────────────────────────────────

    function test_CallerCanSetContenthash() public {
        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(resolver));
        emit ContenthashSet(TEST_CID);
        resolver.setContenthash(TEST_CID);

        // Verify the public resolver was called
        bytes memory stored = mockPublicResolver.contenthash(TEST_NODE);
        assertEq(stored, abi.encodePacked(TEST_CID));
    }

    function test_NonCallerCannotSetContenthash() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                resolver.CALLER_ROLE()
            )
        );
        resolver.setContenthash(TEST_CID);
    }

    function test_ZeroContenthash_Reverts() public {
        vm.prank(caller);
        vm.expectRevert(ENSResolver.ZeroContenthash.selector);
        resolver.setContenthash(bytes32(0));
    }

    // ── setENSNode ──────────────────────────────────────────────────

    function test_AdminCanSetENSNode() public {
        bytes32 newNode = keccak256("newdomain.eth");
        vm.expectEmit(true, true, true, true, address(resolver));
        emit ENSNodeSet(newNode);
        resolver.setENSNode(newNode);
        assertEq(resolver.ensNode(), newNode);
    }

    function test_NonAdminCannotSetENSNode() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                resolver.DEFAULT_ADMIN_ROLE()
            )
        );
        resolver.setENSNode(bytes32(uint256(1)));
    }

    function test_SetENSNode_ZeroNode_Reverts() public {
        vm.expectRevert("ENSResolver: invalid node");
        resolver.setENSNode(bytes32(0));
    }

    // ── setPublicResolver ───────────────────────────────────────────

    function test_AdminCanSetPublicResolver() public {
        address newResolver = address(0x999);
        vm.expectEmit(true, true, true, true, address(resolver));
        emit PublicResolverSet(newResolver);
        resolver.setPublicResolver(newResolver);
        assertEq(address(resolver.publicResolver()), newResolver);
    }

    function test_NonAdminCannotSetPublicResolver() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.AccessControlUnauthorizedAccount.selector,
                attacker,
                resolver.DEFAULT_ADMIN_ROLE()
            )
        );
        resolver.setPublicResolver(address(0x999));
    }

    function test_SetPublicResolver_ZeroAddress_Reverts() public {
        vm.expectRevert("ENSResolver: invalid resolver");
        resolver.setPublicResolver(address(0));
    }
}
