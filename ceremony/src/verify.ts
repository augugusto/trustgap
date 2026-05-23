/**
 * CID verification logic.
 *
 * The verify command:
 * 1. Computes the IPFS CID of a given directory
 * 2. Compares with the expected on-chain CID
 *
 * No Docker, no build step — the directory IS the deployment.
 */

import { computeCID } from './cid.js';
import { createLogger } from './logger.js';

const log = createLogger('verify');

export interface VerifyCIDOptions {
  /** Directory to verify */
  dir: string;
  /** Expected CID from on-chain record */
  expectedCID: string;
}

export interface VerifyCIDResult {
  /** Whether the computed CID matches the expected CID */
  match: boolean;
  /** The CID computed from the directory */
  computedCID: string;
  /** The expected CID from the on-chain record */
  expectedCID: string;
}

/**
 * Verify that a directory produces the expected IPFS CID.
 *
 * @param options - Verification options
 * @returns Verification result
 */
export async function verifyCID(
  options: VerifyCIDOptions,
): Promise<VerifyCIDResult> {
  log.info(`Computing CID for: ${options.dir}`);

  const cid = await computeCID(options.dir);
  const cidStr = cid.toString();

  log.info(`Computed CID: ${cidStr}`);
  log.info(`Expected CID: ${options.expectedCID}`);

  const match = cidStr === options.expectedCID;

  if (match) {
    log.info('✅ CID MATCH — deployment is verified');
  } else {
    log.warn('❌ CID MISMATCH — deployment differs from on-chain record');
  }

  return {
    match,
    computedCID: cidStr,
    expectedCID: options.expectedCID,
  };
}
