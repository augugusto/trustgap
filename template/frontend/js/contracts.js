/**
 * {{NOMBRE}} — Contract interaction layer.
 *
 * Reads on-chain data from the ReleaseProposal and DAOShare contracts.
 * Depends on ethers.js (loaded via script tag) and config.js.
 */

/** Minimal ABI for ReleaseProposal.getLatestReleaseCID() */
const RELEASE_PROPOSAL_ABI = [
  'function getLatestReleaseCID() external view returns (bytes32)',
  'function getLatestRelease() external view returns (tuple(bytes32 cid, address proposer, uint256 timestamp, bool executed))',
];

/** Minimal ABI for DAOShare — read total supply (member count) */
const DAO_SHARE_ABI = [
  'function totalSupply() external view returns (uint256)',
  'function balanceOf(address) external view returns (uint256)',
];

/**
 * Read the latest executed CID from the ReleaseProposal contract.
 *
 * @param {ethers.providers.Provider} provider
 * @returns {Promise<string>} Hex-encoded CID (bytes32)
 */
async function getLatestReleaseCID(provider) {
  const contract = new ethers.Contract(
    CONTRACTS.releaseProposal,
    RELEASE_PROPOSAL_ABI,
    provider
  );
  return await contract.getLatestReleaseCID();
}

/**
 * Read the total member count from DAOShare.
 *
 * @param {ethers.providers.Provider} provider
 * @returns {Promise<number>} Number of members
 */
async function getMemberCount(provider) {
  const contract = new ethers.Contract(
    CONTRACTS.daoShare,
    DAO_SHARE_ABI,
    provider
  );
  const supply = await contract.totalSupply();
  return Number(ethers.utils.formatUnits(supply, 0));
}
