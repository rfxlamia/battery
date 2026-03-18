import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readTokens, writeTokens } from '../../src/storage/token-store.js';

describe('token-store', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'battery-test-'));
    await mkdir(join(tmpDir, '.battery', 'tokens'), { recursive: true });
  });

  it('writes and reads back tokens for an account', async () => {
    const tokens = {
      accessToken: 'sk-ant-test',
      refreshToken: 'rt-test',
      expiresAt: '2026-03-17T10:00:00Z',
    };
    await writeTokens(tmpDir, 'acct-1', tokens);
    const result = await readTokens(tmpDir, 'acct-1');
    expect(result).toEqual(tokens);
  });

  it('returns null when token file does not exist', async () => {
    const result = await readTokens(tmpDir, 'nonexistent');
    expect(result).toBeNull();
  });
});
