// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IENSPublicResolver
/// @notice Minimal interface for the ENS public resolver's contenthash functions
interface IENSPublicResolver {
    /// @notice Set the content hash for an ENS node
    /// @param node The ENS node (namehash of domain)
    /// @param hash The content hash to set (typically encoded IPFS CID)
    function setContenthash(bytes32 node, bytes32 hash) external;

    /// @notice Get the content hash for an ENS node
    /// @param node The ENS node (namehash of domain)
    /// @return The content hash bytes
    function contenthash(bytes32 node) external view returns (bytes memory);
}

/// @title IReleaseRecorder
/// @notice Interface for recording and tracking release proposals
interface IReleaseRecorder {
    /// @notice Emitted when a new release CID is recorded
    event ReleaseRecorded(uint256 indexed index, bytes32 indexed cid);

    /// @notice Record a new release proposal
    /// @param cid The IPFS CID (as bytes32) being proposed
    /// @return index The index of the recorded release
    function recordRelease(bytes32 cid) external returns (uint256 index);

    /// @notice Get the total number of releases recorded
    /// @return count The number of releases
    function getReleaseCount() external view returns (uint256);

    /// @notice Get the CID for a specific release
    /// @param index The release index
    /// @return cid The IPFS CID (as bytes32)
    function getReleaseCID(uint256 index) external view returns (bytes32 cid);
}
