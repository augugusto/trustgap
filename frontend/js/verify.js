/**
 * Trustgap — CID Verification.
 *
 * Compares the build-time EXPECTED_CID against the on-chain
 * ReleaseProposal record to prove this deployment was DAO-approved.
 */

/**
 * Verify that the expected CID matches the on-chain record.
 *
 * @param {string} expectedCID — Build-time CID from config
 * @param {ethers.providers.Provider} provider
 * @returns {Promise<{verified: boolean, expected: string, onChain: string, error?: string}>}
 */
async function verifyDeployment(expectedCID, provider) {
  if (!expectedCID) {
    return {
      verified: false,
      expected: '',
      onChain: '',
      error: 'EXPECTED_CID not set. This deployment was not built through the ceremony.',
    };
  }

  if (!CONTRACTS.releaseProposal) {
    return {
      verified: false,
      expected: expectedCID,
      onChain: '',
      error: 'ReleaseProposal address not configured.',
    };
  }

  try {
    const onChainCID = await getLatestReleaseCID(provider);

    if (!onChainCID || onChainCID === '0x' + '00'.repeat(32)) {
      return {
        verified: false,
        expected: expectedCID,
        onChain: onChainCID,
        error: 'No release recorded on-chain yet.',
      };
    }

    const match = expectedCID.toLowerCase() === onChainCID.toLowerCase();

    return {
      verified: match,
      expected: expectedCID,
      onChain: onChainCID,
      error: match ? null : 'CID mismatch — this deployment does not match the DAO-approved version.',
    };
  } catch (err) {
    return {
      verified: false,
      expected: expectedCID,
      onChain: '',
      error: 'Failed to read on-chain CID: ' + err.message,
    };
  }
}
