import { OAUTH_CLIENT_ID, OAUTH_TOKEN_URL } from '../config/env.js';
import { createPkcePair, generateState } from './pkce.js';
import { startOAuthListener } from './oauth-listener.js';
import { buildAuthorizeUrl } from './oauth-authorize.js';
import { openBrowser } from './browser-launch.js';

export interface TokenResult {
  accessToken: string;
  refreshToken?: string;
  expiresIn: number;
}

interface ExchangeParams {
  code: string;
  codeVerifier: string;
  redirectUri: string;
  state: string;
  fetchImpl: typeof fetch;
}

export async function exchangeCodeForTokens(params: ExchangeParams): Promise<TokenResult> {
  const { code, codeVerifier, redirectUri, state, fetchImpl } = params;

  const body = {
    grant_type: 'authorization_code',
    code,
    client_id: OAUTH_CLIENT_ID,
    code_verifier: codeVerifier,
    redirect_uri: redirectUri,
    state,
  };

  const res = await fetchImpl(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Token exchange failed: HTTP ${res.status}: ${text}`);
  }

  const data = (await res.json()) as {
    access_token: string;
    refresh_token?: string;
    expires_in?: number;
  };

  return {
    accessToken: data.access_token,
    ...(data.refresh_token ? { refreshToken: data.refresh_token } : {}),
    expiresIn: data.expires_in ?? 3600,
  };
}

interface StartOAuthLoginOptions {
  fetchImpl: typeof fetch;
  openBrowserImpl?: (url: string) => Promise<void>;
}

export async function startOAuthLogin(opts: StartOAuthLoginOptions): Promise<TokenResult> {
  const { fetchImpl, openBrowserImpl = openBrowser } = opts;

  const { verifier, challenge } = createPkcePair();
  const state = generateState();

  // Pass expectedState so the listener rejects any callback that doesn't
  // carry the matching state parameter (RFC 6749 §10.12 CSRF protection).
  const listener = await startOAuthListener({ path: '/callback', expectedState: state });
  const redirectUri = `http://localhost:${listener.port}/callback`;

  const authorizeUrl = buildAuthorizeUrl({ redirectUri, state, codeChallenge: challenge });

  try {
    await openBrowserImpl(authorizeUrl);
  } catch (err) {
    await listener.stop();
    throw new Error(`Failed to open browser: ${String(err)}`);
  }

  const code = await listener.codePromise;

  const tokens = await exchangeCodeForTokens({
    code,
    codeVerifier: verifier,
    redirectUri,
    state,
    fetchImpl,
  });

  await listener.stop();
  return tokens;
}
