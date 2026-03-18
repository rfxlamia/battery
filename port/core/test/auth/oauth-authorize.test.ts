import { describe, expect, it } from 'vitest';
import { buildAuthorizeUrl } from '../../src/auth/oauth-authorize.js';
import { OAUTH_AUTHORIZE_URL, OAUTH_CLIENT_ID, OAUTH_SCOPES } from '../../src/config/env.js';

describe('buildAuthorizeUrl', () => {
  it('matches the Swift authorize query shape', () => {
    const url = new URL(buildAuthorizeUrl({
      redirectUri: 'http://localhost:43123/callback',
      state: 'state-123',
      codeChallenge: 'challenge-123',
    }));

    expect(url.origin + url.pathname).toBe(OAUTH_AUTHORIZE_URL);
    expect(url.searchParams.get('client_id')).toBe(OAUTH_CLIENT_ID);
    expect(url.searchParams.get('redirect_uri')).toBe('http://localhost:43123/callback');
    expect(url.searchParams.get('response_type')).toBe('code');
    expect(url.searchParams.get('scope')).toBe(OAUTH_SCOPES);
    expect(url.searchParams.get('code_challenge_method')).toBe('S256');
  });
});
