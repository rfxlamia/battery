import { describe, expect, it } from 'vitest';
import { exchangeCodeForTokens } from '../../src/auth/oauth-login.js';
import { OAUTH_CLIENT_ID, OAUTH_TOKEN_URL } from '../../src/config/env.js';

describe('exchangeCodeForTokens', () => {
  it('posts the Swift-parity authorization_code body', async () => {
    const calls: Array<{ url: string; body: unknown }> = [];
    const fetchStub = async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return new Response(JSON.stringify({
        access_token: 'access',
        refresh_token: 'refresh',
        expires_in: 3600,
      }), { status: 200 });
    };

    const tokens = await exchangeCodeForTokens({
      code: 'code-123',
      codeVerifier: 'verifier-123',
      redirectUri: 'http://localhost:43123/callback',
      state: 'state-123',
      fetchImpl: fetchStub as typeof fetch,
    });

    expect(calls[0]?.url).toBe(OAUTH_TOKEN_URL);
    expect(calls[0]?.body).toMatchObject({
      grant_type: 'authorization_code',
      code: 'code-123',
      client_id: OAUTH_CLIENT_ID,
      code_verifier: 'verifier-123',
      redirect_uri: 'http://localhost:43123/callback',
      state: 'state-123',
    });
    expect(tokens.accessToken).toBe('access');
  });

  it('throws a descriptive auth error on non-200', async () => {
    const fetchStub = async () =>
      new Response('Unauthorized', { status: 401 });
    await expect(
      exchangeCodeForTokens({
        code: 'code',
        codeVerifier: 'verifier',
        redirectUri: 'http://localhost/callback',
        state: 'state',
        fetchImpl: fetchStub as typeof fetch,
      }),
    ).rejects.toThrow(/token exchange failed/i);
  });
});
