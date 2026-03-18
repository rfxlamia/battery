import { describe, expect, it } from 'vitest';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runLoginCommand } from '../../src/auth/run-login-command.js';

describe('runLoginCommand', () => {
  it('propagates browser launch errors', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-fail-'));
    await expect(
      runLoginCommand({
        homeDir,
        fetchImpl: async () => new Response('{}', { status: 200 }) as never,
        startOAuthLoginImpl: async () => {
          throw new Error('Failed to open browser: xdg-open: not found');
        },
      }),
    ).rejects.toThrow(/failed to open browser/i);
  });

  it('persists login output and writes an ok state immediately', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-command-'));

    await runLoginCommand({
      homeDir,
      fetchImpl: async () => new Response(JSON.stringify({
        access_token: 'access',
        refresh_token: 'refresh',
        expires_in: 3600,
      }), { status: 200 }) as never,
      openBrowser: async () => undefined,
      startOAuthLoginImpl: async () => ({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
      }),
      pollOnceImpl: async () => ({
        version: 1,
        status: 'ok',
        updatedAt: new Date().toISOString(),
        freshness: { staleAfterSeconds: 60 },
        account: { id: 'acct-1', name: 'Account 1', planTier: 'unknown', isSelected: true },
        session: { utilization: 0.1, resetsAt: null, isActive: false },
        weekly: { utilization: 0.2, resetsAt: null },
      }),
    });

    const state = JSON.parse(await readFile(join(homeDir, '.battery', 'state.json'), 'utf8'));
    expect(state.status).toBe('ok');
  });
});
