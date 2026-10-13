/**
 * Tests for pure-JS CID computation.
 *
 * Covers:
 * - Determinism: same directory → same CID across multiple calls
 * - Content sensitivity: different files → different CIDs
 * - Structure sensitivity: same files, different layout → different CIDs
 * - Error cases: empty directory, missing directory, empty file
 */

import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { computeCID, computeFileCID } from '../src/cid.js';

function createTempDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'cid-test-'));
}

function writeFile(dir: string, relPath: string, content: string): void {
  const fullPath = path.join(dir, relPath);
  fs.mkdirSync(path.dirname(fullPath), { recursive: true });
  fs.writeFileSync(fullPath, content, 'utf-8');
}

describe('computeCID (directory)', () => {
  it('produces the same CID for the same directory (determinism)', async () => {
    const dir = createTempDir();
    writeFile(dir, 'index.html', '<h1>Hello</h1>');
    writeFile(dir, 'style.css', 'body { color: red; }');

    const cid1 = await computeCID(dir);
    const cid2 = await computeCID(dir);

    expect(cid1.toString()).toBe(cid2.toString());
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('produces different CIDs for different content', async () => {
    const dir1 = createTempDir();
    writeFile(dir1, 'index.html', '<h1>Version A</h1>');

    const dir2 = createTempDir();
    writeFile(dir2, 'index.html', '<h1>Version B</h1>');

    const cid1 = await computeCID(dir1);
    const cid2 = await computeCID(dir2);

    expect(cid1.toString()).not.toBe(cid2.toString());

    fs.rmSync(dir1, { recursive: true, force: true });
    fs.rmSync(dir2, { recursive: true, force: true });
  });

  it('produces different CIDs for same content different file names', async () => {
    const dir1 = createTempDir();
    writeFile(dir1, 'index.html', '<h1>Hello</h1>');

    const dir2 = createTempDir();
    writeFile(dir2, 'main.html', '<h1>Hello</h1>');

    const cid1 = await computeCID(dir1);
    const cid2 = await computeCID(dir2);

    expect(cid1.toString()).not.toBe(cid2.toString());

    fs.rmSync(dir1, { recursive: true, force: true });
    fs.rmSync(dir2, { recursive: true, force: true });
  });

  it('handles nested directories', async () => {
    const dir = createTempDir();
    writeFile(dir, 'index.html', '<h1>Root</h1>');
    writeFile(dir, 'blog/post-1.html', '<h1>Post 1</h1>');
    writeFile(dir, 'blog/post-2.html', '<h1>Post 2</h1>');

    const cid = await computeCID(dir);
    expect(cid.toString()).toBeTruthy();
    expect(cid.toString()).toMatch(/^bafy/);

    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('throws for an empty directory', async () => {
    const dir = createTempDir();
    await expect(computeCID(dir)).rejects.toThrow(/empty/i);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('throws for a non-existent directory', async () => {
    await expect(computeCID('/nonexistent-path-12345')).rejects.toThrow();
  });

  it('handles a single file in directory', async () => {
    const dir = createTempDir();
    writeFile(dir, 'index.html', '<h1>Single</h1>');

    const cid = await computeCID(dir);
    expect(cid.toString()).toBeTruthy();

    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('produces a CID in CIDv1 format', async () => {
    const dir = createTempDir();
    writeFile(dir, 'index.html', '<h1>Format test</h1>');

    const cid = await computeCID(dir);
    const cidStr = cid.toString();

    // CIDv1 (base32) starts with 'b' followed by the multibase prefix
    expect(cidStr.startsWith('b')).toBe(true);
    // CID version should be 1
    expect(cid.version).toBe(1);

    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('computeFileCID (single file)', () => {
  it('produces consistent CID for the same file content', async () => {
    const dir = createTempDir();
    const filePath = path.join(dir, 'test.txt');
    fs.writeFileSync(filePath, 'consistent content');

    const cid1 = await computeFileCID(filePath);
    const cid2 = await computeFileCID(filePath);

    expect(cid1.toString()).toBe(cid2.toString());
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('produces different CIDs for different file content', async () => {
    const dir = createTempDir();
    const file1 = path.join(dir, 'a.txt');
    const file2 = path.join(dir, 'b.txt');
    fs.writeFileSync(file1, 'alpha');
    fs.writeFileSync(file2, 'beta');

    const cid1 = await computeFileCID(file1);
    const cid2 = await computeFileCID(file2);

    expect(cid1.toString()).not.toBe(cid2.toString());
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
