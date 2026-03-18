import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pollOnce } from '../../src/runtime/poll-once.js';
import { batteryStateSchema } from '../../src/contracts/index.js';

const sample200 = {
  five_hour: { utilization: 42.5, resets_at: '2026-03-17T13:00:00Z' },
  seven_day: { utilization: 61.2, resets_at: '2026-03-23T00:00:00Z' },
};

const mockFetch200 = async (_url: string) =>
  new Response(JSON.stringify(sample200), { status: 200 });

const mockFetch401 = async (_url: string) =>
  new Response(JSON.stringify({ error: { type: 'authentication_error' } }), { status: 401 });

describe('pollOnce', () => {
  let homeDir: string;
  const now = new Date('2026-03-17T09:00:00Z').getTime();

  beforeEach(async () => {
    homeDir = await mkdtemp(join(tmpdir(), 'battery-poll-test-'));
    await mkdir(join(homeDir, '.battery', 'tokens'), { recursive: true });

    // Write accounts.json with a selected account
    await writeFile(
      join(homeDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', selected: true },
      ]),
    );

    // Write tokens for the selected account (fresh, no need to refresh)
    await writeFile(
      join(homeDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'valid-token',
        refreshToken: 'rt-valid',
        expiresAt: new Date(now + 2 * 3600 * 1000).toISOString(),
      }),
      { mode: 0o600 },
    );
  });

  it('returns ok state with usage data and validates against batteryStateSchema', async () => {
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir });

    expect(state.status).toBe('ok');
    expect(state.session?.utilization).toBeGreaterThanOrEqual(0);
    expect(state.weekly?.utilization).toBeGreaterThanOrEqual(0);
    expect(state.account?.isSelected).toBe(true);
    expect(state.freshness.staleAfterSeconds).toBeGreaterThan(0);

    // Must parse cleanly with the contract schema
    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });

  it('returns login_required when no account is configured', async () => {
    await writeFile(
      join(homeDir, '.battery', 'accounts.json'),
      JSON.stringify([]),
    );
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir });
    expect(state.status).toBe('login_required');
  });

  it('returns login_required when no token file exists for account', async () => {
    const noTokenDir = await mkdtemp(join(tmpdir(), 'battery-notoken-'));
    await mkdir(join(noTokenDir, '.battery'), { recursive: true });
    await writeFile(
      join(noTokenDir, '.battery', 'accounts.json'),
      JSON.stringify([{ id: 'acct-1', name: 'Alice', planTier: 'pro', selected: true }]),
    );
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir: noTokenDir });
    expect(state.status).toBe('login_required');
  });

  it('returns login_required on 401 when no refresh token exists', async () => {
    // Write tokens with no refresh token — so force-refresh will fail with no_refresh_token
    await writeFile(
      join(homeDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'bad-token',
        expiresAt: new Date(now + 2 * 3600 * 1000).toISOString(),
      }),
      { mode: 0o600 },
    );
    const state = await pollOnce({ fetchImpl: mockFetch401 as typeof fetch, now, homeDir });
    expect(state.status).toBe('login_required');
  });
});
