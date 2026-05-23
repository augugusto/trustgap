// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../lib/Interfaces.sol";

/// @title ENSResolver
/// @notice Wraps ENS public resolver to allow TimelockController-controlled contenthash updates.
///         The TimelockController is granted CALLER_ROLE and is the sole address that can
///         trigger setContenthash on the public resolver for the stored ENS node.
contract ENSResolver is AccessControl {
    /// @notice Role allowed to call setContenthash (granted to TimelockController)
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    /// @notice The ENS public resolver contract address
    IENSPublicResolver public publicResolver;

    /// @notice The ENS node (namehash) this resolver controls
    bytes32 public ensNode;

    /// @notice Emitted when the contenthash is successfully updated
    event ContenthashSet(bytes32 indexed contenthash);

    // ---------- Events for ENS ownership changes ----------
    /// @notice Emitted when the ENS node managed by this contract changes
    event ENSNodeSet(bytes32 indexed node);

    /// @notice Emitted when the public resolver address changes
    event PublicResolverSet(address indexed resolver);

    /// @notice Reverts if the contenthash is zero
    error ZeroContenthash();

    /// @notice Ensures a non-zero contenthash
    /// @param contenthash The content hash bytes32 to validate
    modifier validateContenthash(bytes32 contenthash) {
        if (contenthash == bytes32(0)) revert ZeroContenthash();
        _;
    }

    /// @notice Constructor
    /// @param _publicResolver Address of the ENS public resolver
    /// @param _ensNode The ENS node (namehash) this resolver will manage
    constructor(address _publicResolver, bytes32 _ensNode) {
        publicResolver = IENSPublicResolver(_publicResolver);
        ensNode = _ensNode;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CALLER_ROLE, msg.sender);
    }

    /// @notice Update the contenthash for the managed ENS node.
    ///         Only callable by addresses with CALLER_ROLE (the TimelockController).
    /// @param contenthash The new content hash (bytes32)
    function setContenthash(
        bytes32 contenthash
    ) external onlyRole(CALLER_ROLE) validateContenthash(contenthash) {
        publicResolver.setContenthash(ensNode, contenthash);
        emit ContenthashSet(contenthash);
    }

    /// @notice Update the ENS node this resolver controls.
    ///         Only callable by addresses with DEFAULT_ADMIN_ROLE.
    /// @param _ensNode The new ENS node (namehash)
    function setENSNode(bytes32 _ensNode) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_ensNode != bytes32(0), "ENSResolver: invalid node");
        ensNode = _ensNode;
        emit ENSNodeSet(_ensNode);
    }

    /// @notice Update the ENS public resolver address.
    ///         Only callable by addresses with DEFAULT_ADMIN_ROLE.
    /// @param _publicResolver The new public resolver address
    function setPublicResolver(
        address _publicResolver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_publicResolver != address(0), "ENSResolver: invalid resolver");
        publicResolver = IENSPublicResolver(_publicResolver);
        emit PublicResolverSet(_publicResolver);
    }
}
