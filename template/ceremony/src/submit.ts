/**
 * On-chain proposal calldata builder and transaction submitter.
 *
 * Builds calldata for the release proposal flow:
 * 1. encodeContenthash(cid) → converts a CID to ENS contenthash format
 * 2. buildProposalCalldata(target, contenthash) → creates the action for Governor
 * 3. submitTransaction(...) → signs and broadcasts the proposal
 */

import { ethers } from 'ethers';
import { CID } from 'multiformats/cid';

export interface ProposalAction {
  /** Contract address to call */
  target: string;
  /** ETH value to send (usually 0) */
  value: bigint;
  /** Encoded function calldata */
  data: string;
}

export interface ProposalSubmission {
  /** Transaction hash of the submitted proposal */
  txHash: string;
  /** Governor proposal ID (if available) */
  proposalId?: string;
}

// ABI fragment for ENSResolver.setContenthash
const ENS_RESOLVER_ABI = [
  'function setContenthash(bytes32 contenthash) external',
];

// ABI fragment for ReleaseProposal.recordRelease
const RELEASE_PROPOSAL_ABI = [
  'function recordRelease(bytes32 cid) external returns (uint256 index)',
];

/**
 * Convert an IPFS CID to the ENS contenthash format (bytes32).
 *
 * The contenthash encodes the IPFS CID so it can be stored on-chain
 * via the ENS resolver. The format is the raw SHA-256 digest of the
 * root DAG-PB block, encoded as bytes32 to match our IENSPublicResolver interface.
 *
 * For compatibility with our simplified bytes32 interface, we use the
 * raw multihash digest (32 bytes) directly.
 *
 * @param cid - The IPFS CID to encode
 * @returns A hex-encoded bytes32 contenthash
 */
export function cidToContenthash(cid: CID): string {
  const digest = cid.multihash.digest;
  if (digest.length !== 32) {
    throw new Error(
      `Expected 32-byte digest (SHA-256), got ${digest.length} bytes`,
    );
  }
  return ethers.hexlify(digest);
}

/**
 * Convert an IPFS CID to a bytes32 value suitable for the ReleaseProposal contract.
 * The CID's SHA-256 digest is used as the bytes32 identifier.
 */
export function cidToBytes32(cid: CID): string {
  const digest = cid.multihash.digest;
  if (digest.length !== 32) {
    throw new Error(`Expected 32-byte digest, got ${digest.length} bytes`);
  }
  return ethers.hexlify(digest);
}

/**
 * Build calldata for calling ENSResolver.setContenthash with a contenthash.
 * This is the action data that goes inside a Governor proposal.
 *
 * @param ensResolverAddress - The ENSResolver contract address
 * @param contenthash - The contenthash bytes32 value (from cidToContenthash)
 * @returns ProposalAction ready for Governor.propose()
 */
export function buildProposalCalldata(
  ensResolverAddress: string,
  contenthash: string,
): ProposalAction {
  const iface = new ethers.Interface(ENS_RESOLVER_ABI);
  const data = iface.encodeFunctionData('setContenthash', [contenthash]);

  return {
    target: ensResolverAddress,
    value: 0n,
    data,
  };
}

/**
 * Build calldata for calling ReleaseProposal.recordRelease.
 * Records the CID on-chain as a release proposal.
 */
export function buildRecordReleaseCalldata(
  releaseProposalAddress: string,
  cidBytes32: string,
): ProposalAction {
  const iface = new ethers.Interface(RELEASE_PROPOSAL_ABI);
  const data = iface.encodeFunctionData('recordRelease', [cidBytes32]);

  return {
    target: releaseProposalAddress,
    value: 0n,
    data,
  };
}

/**
 * Submit a Governor proposal transaction.
 * The proposal contains one or more actions that will be executed
 * through the TimelockController after the voting and delay periods.
 *
 * @param governorAddress - OZ Governor contract address
 * @param actions - Array of proposal actions (targets + values + calldatas)
 * @param description - Human-readable proposal description
 * @param signer - ethers.js Signer or Wallet instance
 * @returns The transaction hash and proposal ID
 */
export async function submitProposal(
  governorAddress: string,
  actions: ProposalAction[],
  description: string,
  signer: ethers.Signer,
): Promise<ProposalSubmission> {
  const iface = new ethers.Interface([
    'function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) external returns (uint256 proposalId)',
  ]);

  const targets = actions.map((a) => a.target);
  const values = actions.map((a) => a.value);
  const calldatas = actions.map((a) => a.data);

  const data = iface.encodeFunctionData('propose', [
    targets,
    values,
    calldatas,
    description,
  ]);

  const tx = await signer.sendTransaction({
    to: governorAddress,
    data,
  });

  const receipt = await tx.wait();

  if (!receipt) {
    throw new Error('Transaction receipt not found');
  }

  return {
    txHash: receipt.hash,
  };
}

/**
 * Build the full proposal calldata for a single CID release.
 * Creates the contenthash from the CID, then builds Governor proposal calldata
 * targeting the ReleaseProposal contract.
 *
 * @param releaseProposalAddress - The ReleaseProposal contract address
 * @param cid - The IPFS CID of the build
 * @returns ProposalAction for recording the release
 */
export function buildReleaseAction(
  releaseProposalAddress: string,
  cid: CID,
): ProposalAction {
  const cidBytes32 = cidToBytes32(cid);
  return buildRecordReleaseCalldata(releaseProposalAddress, cidBytes32);
}
