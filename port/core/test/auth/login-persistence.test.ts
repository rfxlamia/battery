import { describe, expect, it } from 'vitest';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { persistLoginResult } from '../../src/auth/login-persistence.js';

describe('persistLoginResult', () => {
  it('creates Account 1 and selects it on the first login', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-persist-'));

    const result = await persistLoginResult(homeDir, {
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresIn: 3600,
    });

    const accounts = JSON.parse(await readFile(join(homeDir, '.battery', 'accounts.json'), 'utf8'));
    expect(accounts[0]).toMatchObject({
      name: 'Account 1',
      planTier: 'unknown',
      isDefault: true,
    });
    expect(result.accountId).toBe(accounts[0].id);
  });

  it('replaces tokens for the selected account on re-auth', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-persist-'));

    // First login
    const first = await persistLoginResult(homeDir, {
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresIn: 3600,
    });

    // Second login (re-auth)
    const second = await persistLoginResult(homeDir, {
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
      expiresIn: 3600,
    });

    expect(second.accountId).toBe(first.accountId);

    const accounts = JSON.parse(await readFile(join(homeDir, '.battery', 'accounts.json'), 'utf8'));
    expect(accounts).toHaveLength(1);

    const tokenFile = await readFile(join(homeDir, '.battery', 'tokens', `${second.accountId}.json`), 'utf8');
    const tokens = JSON.parse(tokenFile);
    expect(tokens.accessToken).toBe('access-2');
  });

  it('creates Account 2 when accounts exist but none is selected', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-persist-'));

    // First login creates Account 1
    await persistLoginResult(homeDir, { accessToken: 'a1', refreshToken: 'r1', expiresIn: 3600 });

    // Remove the selected-account-id file to simulate "no selection"
    const { unlink } = await import('node:fs/promises');
    await unlink(join(homeDir, '.battery', 'selected-account-id'));

    const second = await persistLoginResult(homeDir, { accessToken: 'a2', refreshToken: 'r2', expiresIn: 3600 });

    const accounts = JSON.parse(await readFile(join(homeDir, '.battery', 'accounts.json'), 'utf8'));
    expect(accounts).toHaveLength(2);
    expect(accounts[1]).toMatchObject({ name: 'Account 2' });
    expect(second.accountId).toBe(accounts[1].id);
  });
});
