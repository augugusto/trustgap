/**
 * Pure-JS IPFS CID computation for a local directory.
 *
 * Matches the algorithm used by `ipfs add -r --cid-version 1 --raw-leaves`:
 * - Each file becomes a UnixFS DAG-PB leaf node (type=file)
 * - Each directory becomes a UnixFS DAG-PB node (type=directory) with links to children
 * - The root CID is the hash of the top-level directory DAG-PB block
 * - Links are sorted by name for deterministic ordering
 *
 * Dependencies: @ipld/dag-pb, ipfs-unixfs, multiformats
 */

import { encode as dagPbEncode, type PBLink } from '@ipld/dag-pb';
import { UnixFS } from 'ipfs-unixfs';
import { CID } from 'multiformats/cid';
import { sha256 } from 'multiformats/hashes/sha2';
import * as fs from 'node:fs/promises';
import * as path from 'node:path';

// Multicodec code for dag-pb
const DAG_PB_CODEC = 0x70;

/** Internal cache of a processed node with its CID and block size */
interface CachedNode {
  cid: CID;
  size: number;
}

/**
 * Create a DAG-PB leaf node for a single file.
 * The file content is wrapped in a UnixFS Data protobuf (type=file)
 * and encoded as a DAG-PB block with no links.
 */
async function createFileNode(content: Uint8Array): Promise<CachedNode> {
  const file = new UnixFS({ type: 'file', data: content });
  const data = file.marshal();
  const nodeBytes = dagPbEncode({ Data: data, Links: [] });
  const hash = await sha256.digest(nodeBytes);
  const cid = CID.createV1(DAG_PB_CODEC, hash);
  return { cid, size: nodeBytes.length };
}

/**
 * Create a DAG-PB directory node with links to all children.
 * Children are sorted by name for deterministic CID computation.
 */
async function createDirNode(
  children: Array<{ name: string; node: CachedNode }>,
): Promise<CachedNode> {
  if (children.length === 0) {
    throw new Error('Cannot create directory node with no children');
  }

  // Sort by name for deterministic ordering (matches IPFS behavior)
  children.sort((a, b) => a.name.localeCompare(b.name));

  // The cast is types-only. TS 5.7+ parameterises Uint8Array over its buffer
  // type, and @ipld/dag-pb's PBLink pins ArrayBuffer while the CID produced
  // here carries ArrayBufferLike. Same bytes at runtime.
  const links: PBLink[] = children.map((c) => ({
    Name: c.name,
    Hash: c.node.cid as unknown as PBLink['Hash'],
    Tsize: c.node.size,
  }));

  const dir = new UnixFS({ type: 'directory' });
  const data = dir.marshal();
  const nodeBytes = dagPbEncode({ Data: data, Links: links });
  const hash = await sha256.digest(nodeBytes);
  const cid = CID.createV1(DAG_PB_CODEC, hash);
  return { cid, size: nodeBytes.length };
}

/**
 * Recursively process a directory: create file nodes for each file
 * and directory nodes for each subdirectory, bottom-up.
 */
async function processDir(dirPath: string): Promise<CachedNode> {
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  const childNodes: Array<{ name: string; node: CachedNode }> = [];

  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name);

    if (entry.isFile()) {
      const content = await fs.readFile(fullPath);
      const node = await createFileNode(content);
      childNodes.push({ name: entry.name, node });
    } else if (entry.isDirectory()) {
      const node = await processDir(fullPath);
      childNodes.push({ name: entry.name, node });
    }
    // Skip symlinks and other non-regular entries
  }

  return createDirNode(childNodes);
}

/**
 * Compute the IPFS CIDv1 of a directory using pure-JS, matching the
 * algorithm used by `ipfs add -r --cid-version 1 --raw-leaves`.
 *
 * @param dirPath - Path to the directory to compute CID for
 * @returns The root CID of the directory
 * @throws {Error} If the directory is empty or doesn't exist
 */
export async function computeCID(dirPath: string): Promise<CID> {
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  if (entries.length === 0) {
    throw new Error(`Cannot compute CID for empty directory: ${dirPath}`);
  }
  const root = await processDir(dirPath);
  return root.cid;
}

/**
 * Compute an IPFS CID for a single file (not wrapped in a directory).
 * Useful for directly hashing a build artifact.
 */
export async function computeFileCID(filePath: string): Promise<CID> {
  const content = await fs.readFile(filePath);
  const node = await createFileNode(content);
  return node.cid;
}
