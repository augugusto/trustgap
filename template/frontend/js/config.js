/**
 * {{NOMBRE}} — Build-time configuration.
 *
 * These constants are embedded in the static frontend and verified
 * against on-chain records at page load.
 *
 * BEFORE DEPLOYING: set EXPECTED_CID and CONTRACTS to match
 * the deployed contract addresses and approved IPFS CID.
 */

/** Expected IPFS CID of this deployment (SHA-256 digest as hex) */
const EXPECTED_CID = '';

/** Base Sepolia chain ID */
const DEFAULT_CHAIN_ID = 84532;

/** Base Sepolia display name */
const DEFAULT_CHAIN_NAME = 'Base Sepolia';

/** On-chain contract addresses */
const CONTRACTS = {
  /** ReleaseProposal — reads the latest executed CID */
  releaseProposal: '',
  /** DAOShare — reads total members */
  daoShare: '',
  /** ENSResolver — reads ENS node */
  ensResolver: '',
};

/** ENS domain name (e.g. "mydao.eth") */
const ENS_DOMAIN = '{{DOMINIO}}';

/** Radicle repo URL for the project (optional) */
const RADICLE_REPO_URL = '';
