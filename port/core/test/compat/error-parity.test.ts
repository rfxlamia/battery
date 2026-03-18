import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import { mkdtemp, writeFile, mkdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadExpected, SAMPLE_200_RAW } from './compat-test-harness.js';
import { fetchUsage } from '../../src/api/anthropic-api.js';
import { pollOnce } from '../../src/runtime/poll-once.js';
import { batteryStateSchema } from '../../src/contracts/index.js';
import { OAUTH_TOKEN_URL } from '../../src/config/env.js';

describe('error parity', () => {
  it('maps 401 to unauthorized error kind', async () => {
    const expected = await loadExpected<{ kind: string }>('errors/unauthorized.expected.json');
    const fetch401 = async () =>
      new Response(JSON.stringify({ error: { type: 'authentication_error' } }), { status: 401 });

    await expect(fetchUsage(fetch401 as typeof fetch, 'bad')).rejects.toMatchObject({
      kind: expected.kind,
    });
  });

  it('maps 429 to rate_limited with retryAfterSeconds', async () => {
    const expected = await loadExpected<{ kind: string; retryAfterSeconds: number }>('errors/rate-limited.expected.json');
    const fetch429 = async () =>
      new Response('', {
        status: 429,
        headers: { 'Retry-After': String(expected.retryAfterSeconds) },
      });

    await expect(fetchUsage(fetch429 as typeof fetch, 'token')).rejects.toMatchObject({
      kind: expected.kind,
      retryAfterSeconds: expected.retryAfterSeconds,
    });
  });
});

describe('auth lifecycle parity', () => {
  let homeDir: string;
  const now = new Date('2026-03-17T09:00:00Z').getTime();

  beforeEach(async () => {
    homeDir = await mkdtemp(join(tmpdir(), 'battery-auth-compat-'));
    await mkdir(join(homeDir, '.battery', 'tokens'), { recursive: true });

    await writeFile(
      join(homeDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', selected: true },
      ]),
    );
  });

  afterEach(async () => {
    await rm(homeDir, { recursive: true, force: true });
  });

  it('force-refreshes after 401 and retries successfully', async () => {
    const expected = await loadExpected<{ status: string }>('errors/refresh-after-401.expected.json');

    // Write tokens that will trigger a 401 on first try
    await writeFile(
      join(homeDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'expired-token',
        refreshToken: 'rt-valid',
        expiresAt: new Date(now + 2 * 3600 * 1000).toISOString(),
      }),
      { mode: 0o600 },
    );

    let callCount = 0;
    const fetchImpl = async (url: string, init?: RequestInit) => {
      // Token refresh endpoint
      if (url === OAUTH_TOKEN_URL) {
        return new Response(
          JSON.stringify({
            access_token: 'fresh-token',
            refresh_token: 'rt-new',
            expires_in: 3600,
          }),
          { status: 200 },
        );
      }

      // Usage API: first call returns 401, second succeeds
      callCount++;
      if (callCount === 1) {
        return new Response(
          JSON.stringify({ error: { type: 'authentication_error' } }),
          { status: 401 },
        );
      }
      return new Response(JSON.stringify(SAMPLE_200_RAW), { status: 200 });
    };

    const state = await pollOnce({
      fetchImpl: fetchImpl as typeof fetch,
      now,
      homeDir,
    });

    expect(state.status).toBe(expected.status);
    expect(state.account?.isSelected).toBe(true);

    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });

  it('emits login_required when no refresh token exists after 401', async () => {
    const expected = await loadExpected<{ status: string }>('errors/no-refresh-token.expected.json');

    // Tokens with no refresh token
    await writeFile(
      join(homeDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'bad-token',
        expiresAt: new Date(now + 2 * 3600 * 1000).toISOString(),
      }),
      { mode: 0o600 },
    );

    const fetch401 = async () =>
      new Response(
        JSON.stringify({ error: { type: 'authentication_error' } }),
        { status: 401 },
      );

    const state = await pollOnce({
      fetchImpl: fetch401 as typeof fetch,
      now,
      homeDir,
    });

    expect(state.status).toBe(expected.status);

    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });

  it('refreshes near-expiry tokens before polling', async () => {
    // Tokens that expire within the 300s buffer — forces refresh before API call
    await writeFile(
      join(homeDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'about-to-expire',
        refreshToken: 'rt-valid',
        expiresAt: new Date(now + 60 * 1000).toISOString(), // expires in 60s — within 300s buffer
      }),
      { mode: 0o600 },
    );

    const fetchImpl = async (url: string) => {
      if (url === OAUTH_TOKEN_URL) {
        return new Response(
          JSON.stringify({
            access_token: 'refreshed-token',
            refresh_token: 'rt-new',
            expires_in: 3600,
          }),
          { status: 200 },
        );
      }
      return new Response(JSON.stringify(SAMPLE_200_RAW), { status: 200 });
    };

    const state = await pollOnce({
      fetchImpl: fetchImpl as typeof fetch,
      now,
      homeDir,
    });

    expect(state.status).toBe('ok');
    expect(state.account?.isSelected).toBe(true);

    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });
});
