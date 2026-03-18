import type { StoredTokens } from '../storage/token-store.js';
import { makeTokenError } from '../api/api-errors.js';
import { ANTHROPIC_API_BASE_URL } from '../config/env.js';

const REFRESH_BUFFER_SECONDS = 300;
const ANTHROPIC_CLIENT_ID = 'claude-ai';

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

  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: tokens.refreshToken,
    client_id: ANTHROPIC_CLIENT_ID,
  });

  let response: Response;
  try {
    response = await fetchImpl(`${ANTHROPIC_API_BASE_URL}/oauth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });
  } catch (err) {
    throw makeTokenError('network_error', `Network error during token refresh: ${String(err)}`);
  }

  if (!response.ok) {
    throw makeTokenError('refresh_failed', `Token refresh failed with status ${response.status}`, {
      statusCode: response.status,
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
