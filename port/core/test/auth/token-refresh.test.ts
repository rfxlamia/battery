import { describe, expect, it } from 'vitest';
import { refreshIfNeeded } from '../../src/auth/token-refresh.js';
import type { StoredTokens } from '../../src/storage/token-store.js';

// Token that expires in 2 hours (well outside refresh buffer)
const freshTokens: StoredTokens = {
  accessToken: 'fresh-access',
  refreshToken: 'rt-valid',
  expiresAt: new Date(Date.now() + 2 * 3600 * 1000).toISOString(),
};

// Token that expires in 2 minutes (within 5-minute buffer)
const expiringTokens: StoredTokens = {
  accessToken: 'expiring-access',
  refreshToken: 'rt-valid',
  expiresAt: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
};

// Token with no refresh token
const tokensWithoutRefresh: StoredTokens = {
  accessToken: 'access-no-refresh',
  expiresAt: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
};

const successRefreshFetch = async (_url: string, _init?: RequestInit) =>
  new Response(
    JSON.stringify({
      access_token: 'new-access-token',
      refresh_token: 'new-refresh-token',
      expires_in: 3600,
    }),
    { status: 200 },
  );

describe('refreshIfNeeded', () => {
  it('returns existing tokens when not near expiry', async () => {
    const result = await refreshIfNeeded(freshTokens, successRefreshFetch);
    expect(result.accessToken).toBe('fresh-access');
  });

  it('refreshes tokens when within 5-minute buffer', async () => {
    const result = await refreshIfNeeded(expiringTokens, successRefreshFetch);
    expect(result.accessToken).toBe('new-access-token');
    expect(result.refreshToken).toBe('new-refresh-token');
  });

  it('uses the Swift parity token endpoint and request body', async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    const fetchSpy = async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init });
      return successRefreshFetch(String(url), init);
    };

    await refreshIfNeeded(expiringTokens, fetchSpy as typeof fetch);

    expect(calls).toHaveLength(1);
    expect(calls[0]?.url).toBe('https://platform.claude.com/v1/oauth/token');
    expect(calls[0]?.init?.headers).toMatchObject({
      'Content-Type': 'application/json',
      'User-Agent': 'Battery/0.2.4',
    });
    expect(JSON.parse(String(calls[0]?.init?.body))).toMatchObject({
      grant_type: 'refresh_token',
      refresh_token: 'rt-valid',
      client_id: '9d1c250a-e61b-44d9-88ed-5944d1962f5e',
      scope: 'user:profile user:inference',
    });
  });

  it('throws no_refresh_token when refresh is needed but no refresh token exists', async () => {
    await expect(refreshIfNeeded(tokensWithoutRefresh, successRefreshFetch)).rejects.toMatchObject({
      kind: 'no_refresh_token',
    });
  });

  it('throws refresh_failed on non-200 response', async () => {
    const fail400 = async () => new Response('{"error":"invalid_grant"}', { status: 400 });
    await expect(refreshIfNeeded(expiringTokens, fail400)).rejects.toMatchObject({
      kind: 'refresh_failed',
    });
  });

  it('always refreshes when force=true regardless of expiry', async () => {
    const result = await refreshIfNeeded(freshTokens, successRefreshFetch, { force: true });
    expect(result.accessToken).toBe('new-access-token');
  });
});
