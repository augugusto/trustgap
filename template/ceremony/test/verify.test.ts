/**
 * Tests for CID verification.
 *
 * Covers:
 * - CID match detection
 * - CID mismatch detection
 * - Error cases
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('verifyCID', () => {
  beforeEach(() => {
    vi.resetModules();
  });

  it('detects matching CIDs', async () => {
    vi.doMock('../src/cid.js', () => ({
      computeCID: vi.fn().mockResolvedValue({
        toString: () => 'bafybeigoodcid1234567890123456789012345678901234567890',
      }),
    }));

    const { verifyCID } = await import('../src/verify.js');
    const result = await verifyCID({
      dir: '/tmp/test-dir',
      expectedCID: 'bafybeigoodcid1234567890123456789012345678901234567890',
    });

    expect(result.match).toBe(true);
    expect(result.computedCID).toBe(result.expectedCID);
  });

  it('detects CID mismatch', async () => {
    vi.doMock('../src/cid.js', () => ({
      computeCID: vi.fn().mockResolvedValue({
        toString: () => 'bafybeiwrongcid1234567890123456789012345678901234567890',
      }),
    }));

    const { verifyCID } = await import('../src/verify.js');
    const result = await verifyCID({
      dir: '/tmp/test-dir',
      expectedCID: 'bafybeigoodcid1234567890123456789012345678901234567890',
    });

    expect(result.match).toBe(false);
    expect(result.computedCID).not.toBe(result.expectedCID);
  });

  it('returns both CIDs for inspection', async () => {
    const expected = 'bafybeiexpected1234567890123456789012345678901234567890';
    const computed = 'bafybeicomputed1234567890123456789012345678901234567890';

    vi.doMock('../src/cid.js', () => ({
      computeCID: vi.fn().mockResolvedValue({
        toString: () => computed,
      }),
    }));

    const { verifyCID } = await import('../src/verify.js');
    const result = await verifyCID({
      dir: '/tmp/test-dir',
      expectedCID: expected,
    });

    expect(result.computedCID).toBe(computed);
    expect(result.expectedCID).toBe(expected);
  });
});

describe('submit module', () => {
  it('builds proposal calldata for ENSResolver', async () => {
    const { buildProposalCalldata, cidToContenthash } = await import('../src/submit.js');
    const { CID } = await import('multiformats/cid');
    const { sha256 } = await import('multiformats/hashes/sha2');

    const hash = await sha256.digest(new TextEncoder().encode('test-cid-data'));
    const mockCid = CID.createV1(0x70, hash);
    const contenthash = cidToContenthash(mockCid);

    const action = buildProposalCalldata(
      '0x1234567890123456789012345678901234567890',
      contenthash,
    );

    expect(action.target).toBe('0x1234567890123456789012345678901234567890');
    expect(action.value).toBe(0n);
    expect(action.data).toBeTruthy();
    expect(action.data).toMatch(/^0x/);
  });

  it('builds record release calldata for ReleaseProposal', async () => {
    const { buildReleaseAction } = await import('../src/submit.js');
    const { CID } = await import('multiformats/cid');
    const { sha256 } = await import('multiformats/hashes/sha2');

    const hash = await sha256.digest(new TextEncoder().encode('test-cid-data-release'));
    const mockCid = CID.createV1(0x70, hash);
    const action = buildReleaseAction(
      '0x2234567890123456789012345678901234567890',
      mockCid,
    );

    expect(action.target).toBe('0x2234567890123456789012345678901234567890');
    expect(action.value).toBe(0n);
    expect(action.data).toBeTruthy();
  });
});
