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
