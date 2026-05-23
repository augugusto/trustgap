#!/usr/bin/env node

/**
 * Ceremony CLI — CID computation, verification, IPFS upload, and on-chain submission.
 *
 * Usage:
 *   ceremony cid <dir>        Compute IPFS CID of a directory
 *   ceremony verify <dir> <cid>  Verify a directory produces the expected CID
 *   ceremony ipfs <dir>       Upload directory to IPFS
 *   ceremony submit <cid>     Build on-chain proposal calldata
 *
 * Each subcommand has its own --help with detailed options.
 */

import { Command } from 'commander';
import { verifyCID } from './verify.js';
import { uploadToIPFS, pinCID } from './ipfs.js';
import { buildProposalCalldata, cidToContenthash } from './submit.js';
import { computeCID } from './cid.js';

const program = new Command();

program
  .name('ceremony')
  .description('Trustgap Ceremony CLI')
  .version('0.2.0')
  .hook('preAction', () => {
    // Global pre-checks can go here
  });

// ─── cid ─────────────────────────────────────────────────────────
program
  .command('cid')
  .description('Compute IPFS CID of a directory')
  .requiredOption('--dir <path>', 'Directory to compute CID for')
  .action(async (options) => {
    try {
      const cid = await computeCID(options.dir);
      console.log(JSON.stringify({
        cid: cid.toString(),
        dir: options.dir,
      }, null, 2));
      process.exit(0);
    } catch (err) {
      console.error('CID computation failed:', (err as Error).message);
      process.exit(1);
    }
  });

// ─── verify ──────────────────────────────────────────────────────
program
  .command('verify')
  .description('Verify a directory produces the expected CID')
  .requiredOption('--dir <path>', 'Directory to verify')
  .requiredOption('--expected-cid <cid>', 'Expected CID to compare against')
  .action(async (options) => {
    try {
      const result = await verifyCID({
        dir: options.dir,
        expectedCID: options.expectedCid,
      });

      console.log(JSON.stringify(result, null, 2));
      process.exit(result.match ? 0 : 1);
    } catch (err) {
      console.error('Verification failed:', (err as Error).message);
      process.exit(1);
    }
  });

// ─── ipfs ────────────────────────────────────────────────────────
program
  .command('ipfs')
  .description('Upload directory to IPFS')
  .requiredOption('--dir <path>', 'Directory to upload')
  .option(
    '--api <url>',
    'Kubo RPC API URL',
    'http://127.0.0.1:5001',
  )
  .option('--pin', 'Pin the uploaded CID', false)
  .action(async (options) => {
    try {
      console.log(`Uploading ${options.dir} to IPFS node at ${options.api}...`);

      const uploadResult = await uploadToIPFS(options.dir, options.api);
      console.log(JSON.stringify({
        status: 'uploaded',
        cid: uploadResult.cidStr,
        totalBytes: uploadResult.totalBytes,
      }, null, 2));

      if (options.pin) {
        console.log('Pinning CID...');
        const pinResult = await pinCID(uploadResult.cid, options.api);
        console.log(JSON.stringify({
          status: pinResult.pinned ? 'pinned' : 'pin_failed',
          cid: pinResult.cid.toString(),
          service: pinResult.service,
        }, null, 2));
      }

      process.exit(0);
    } catch (err) {
      console.error('IPFS upload failed:', (err as Error).message);
      process.exit(1);
    }
  });

// ─── submit ──────────────────────────────────────────────────────
program
  .command('submit')
  .description('Build release proposal calldata (does NOT send tx)')
  .requiredOption('--cid <cid>', 'IPFS CID to submit (string format, e.g. bafy...)')
  .requiredOption(
    '--resolver <address>',
    'ENSResolver contract address (for setContenthash)',
  )
  .option(
    '--release-proposal <address>',
    'ReleaseProposal contract address (for recordRelease, alternative to --resolver)',
  )
  .action(async (options) => {
    try {
      // Parse CID from string
      const { CID } = await import('multiformats/cid');
      const cid = CID.parse(options.cid);

      if (options.releaseProposal) {
        // Build ReleaseProposal calldata
        const { buildReleaseAction } = await import('./submit.js');
        const action = buildReleaseAction(options.releaseProposal, cid);

        console.log(JSON.stringify({
          action: 'recordRelease',
          target: action.target,
          value: action.value.toString(),
          data: action.data,
        }, null, 2));
      } else {
        // Build ENSResolver.setContenthash calldata
        const contenthash = cidToContenthash(cid);
        const action = buildProposalCalldata(options.resolver, contenthash);

        console.log(JSON.stringify({
          action: 'setContenthash',
          contenthash,
          target: action.target,
          value: action.value.toString(),
          data: action.data,
        }, null, 2));
      }

      process.exit(0);
    } catch (err) {
      console.error('Submit failed:', (err as Error).message);
      process.exit(1);
    }
  });

// Parse and run
program.parse();
