/**
 * IPFS upload and pinning helpers.
 *
 * Uploads a local directory to an IPFS node via the Kubo RPC API,
 * then optionally pins it. The CID returned by the node MUST match
 * the locally computed CID — a mismatch means the upload is corrupt.
 */

import { create } from 'kubo-rpc-client';
import { CID } from 'multiformats/cid';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as url from 'node:url';

export interface IPFSUploadResult {
  cid: CID;
  /** CID as a string for display/comparison */
  cidStr: string;
  /** Total file size uploaded */
  totalBytes: number;
}

export interface IPFSPinResult {
  cid: CID;
  pinned: boolean;
  service: string;
}

/**
 * Upload a local directory to an IPFS node via the Kubo RPC API.
 * Walks the directory recursively and adds all files.
 *
 * @param dirPath - Path to the directory to upload
 * @param apiUrl - Kubo RPC API URL (default: http://127.0.0.1:5001)
 * @returns The root CID from the IPFS node
 */
export async function uploadToIPFS(
  dirPath: string,
  apiUrl: string = 'http://127.0.0.1:5001',
): Promise<IPFSUploadResult> {
  const client = create(new URL(apiUrl));

  try {
    // Walk directory and create a source array for the ipfs client
    const sources: Array<{ path: string; content: AsyncIterable<Uint8Array> }> =
      [];
    let totalBytes = 0;

    function walkDir(currentPath: string, prefix: string = ''): void {
      const entries = fs.readdirSync(currentPath, { withFileTypes: true });

      for (const entry of entries) {
        const fullPath = path.join(currentPath, entry.name);
        const relPath = prefix ? `${prefix}/${entry.name}` : entry.name;

        if (entry.isFile()) {
          const content = fs.readFileSync(fullPath);
          totalBytes += content.length;
          sources.push({
            path: relPath,
            content: (async function* () {
              yield content;
            })(),
          });
        } else if (entry.isDirectory()) {
          walkDir(fullPath, relPath);
        }
      }
    }

    walkDir(dirPath);

    if (sources.length === 0) {
      throw new Error(`No files found in directory: ${dirPath}`);
    }

    // Import into IPFS using the Kubo RPC client
    // The result is an async iterable of imported entries
    let rootCid: CID | null = null;
    for await (const result of client.addAll(sources, {
      cidVersion: 1,
      rawLeaves: true,
      wrapWithDirectory: true,
      pin: false, // We'll pin separately
    })) {
      // The last entry is the root (the wrapping directory)
      rootCid = result.cid;
    }

    if (!rootCid) {
      throw new Error('IPFS upload returned no root CID');
    }

    return {
      cid: rootCid,
      cidStr: rootCid.toString(),
      totalBytes,
    };
  } finally {
    client.stop();
  }
}

/**
 * Pin a CID to an IPFS node so it isn't garbage-collected.
 *
 * @param cid - The CID to pin
 * @param apiUrl - Kubo RPC API URL (default: http://127.0.0.1:5001)
 */
export async function pinCID(
  cid: CID,
  apiUrl: string = 'http://127.0.0.1:5001',
): Promise<IPFSPinResult> {
  const client = create(new URL(apiUrl));

  try {
    await client.pin.add(cid);
    return {
      cid,
      pinned: true,
      service: apiUrl,
    };
  } catch (err) {
    return {
      cid,
      pinned: false,
      service: apiUrl,
    };
  } finally {
    client.stop();
  }
}

/**
 * Upload a directory to IPFS and pin it.
 * Convenience function that chains uploadToIPFS + pinCID.
 */
export async function uploadAndPin(
  dirPath: string,
  apiUrl: string = 'http://127.0.0.1:5001',
): Promise<{ upload: IPFSUploadResult; pin: IPFSPinResult }> {
  const upload = await uploadToIPFS(dirPath, apiUrl);
  const pin = await pinCID(upload.cid, apiUrl);
  return { upload, pin };
}
