import type { StoredTokens } from '../storage/token-store.js';
import { makeTokenError } from '../api/api-errors.js';
import {
  BATTERY_USER_AGENT,
  OAUTH_CLIENT_ID,
  OAUTH_SCOPES,
  OAUTH_TOKEN_URL,
} from '../config/env.js';

const REFRESH_BUFFER_SECONDS = 300;

interface RefreshOptions {
  force?: boolean;
}

interface RefreshResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
}

export async function refreshIfNeeded(
  tokens: StoredTokens,
  fetchImpl: typeof fetch,
  options: RefreshOptions = {},
): Promise<StoredTokens> {
  const expiresAt = new Date(tokens.expiresAt).getTime();
  const nowMs = Date.now();
  const secondsUntilExpiry = (expiresAt - nowMs) / 1000;

  const needsRefresh = options.force === true || secondsUntilExpiry <= REFRESH_BUFFER_SECONDS;

  if (!needsRefresh) {
    return tokens;
  }

  if (!tokens.refreshToken) {
    throw makeTokenError('no_refresh_token', 'No refresh token available — re-authentication required');
  }

  const body = JSON.stringify({
    grant_type: 'refresh_token',
    refresh_token: tokens.refreshToken,
    client_id: OAUTH_CLIENT_ID,
    scope: OAUTH_SCOPES,
  });

  let response: Response;
  try {
    response = await fetchImpl(OAUTH_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': BATTERY_USER_AGENT,
      },
      body,
    });
  } catch (err) {
    throw makeTokenError('network_error', `Network error during token refresh: ${String(err)}`);
  }

  if (!response.ok) {
    const bodyText = await response.text().catch(() => '');
    throw makeTokenError('refresh_failed', `Token refresh failed with status ${response.status}`, {
      statusCode: response.status,
      body: bodyText,
    });
  }

  const data = (await response.json()) as RefreshResponse;
  const expiresIn = data.expires_in ?? 3600;

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token ?? tokens.refreshToken,
    expiresAt: new Date(nowMs + expiresIn * 1000).toISOString(),
  };
}
