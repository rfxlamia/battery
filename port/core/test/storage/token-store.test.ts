import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, mkdir, stat, chmod, writeFile, readFile } from 'node:fs/promises';
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
      expiresAt: '2026-03-17T10:00:00.000Z',
    };
    await writeTokens(tmpDir, 'acct-1', tokens);
    const result = await readTokens(tmpDir, 'acct-1');
    expect(result).toEqual(tokens);
  });

  it('returns null when token file does not exist', async () => {
    const result = await readTokens(tmpDir, 'nonexistent');
    expect(result).toBeNull();
  });

  it('re-hardens directory and token file permissions on write', async () => {
    const tokensDir = join(tmpDir, '.battery', 'tokens');
    await chmod(tokensDir, 0o755);

    await writeTokens(tmpDir, 'acct-1', {
      accessToken: 'sk-ant-test',
      refreshToken: 'rt-test',
      expiresAt: '2026-03-17T10:00:00Z',
    });

    const dirMode = (await stat(tokensDir)).mode & 0o777;
    const fileMode = (await stat(join(tokensDir, 'acct-1.json'))).mode & 0o777;

    expect(dirMode).toBe(0o700);
    expect(fileMode).toBe(0o600);
  });

  it('reads the Swift token file format with millisecond expiresAt values', async () => {
    await writeFile(
      join(tmpDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'sk-ant-test',
        refreshToken: 'rt-test',
        expiresAt: 1773741600000,
      }),
    );

    const result = await readTokens(tmpDir, 'acct-1');
    expect(result?.expiresAt).toBe(new Date(1773741600000).toISOString());
  });

  it('writes tokens back in the Swift-compatible millisecond format', async () => {
    await writeTokens(tmpDir, 'acct-1', {
      accessToken: 'sk-ant-test',
      refreshToken: 'rt-test',
      expiresAt: '2026-03-17T10:00:00.000Z',
    });

    const raw = JSON.parse(await readFile(join(tmpDir, '.battery', 'tokens', 'acct-1.json'), 'utf8'));
    expect(typeof raw.expiresAt).toBe('number');
  });
});
