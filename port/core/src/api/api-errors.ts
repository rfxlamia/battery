export interface ApiError {
  kind: 'unauthorized' | 'rate_limited' | 'server_error' | 'network_error' | 'decoding_error';
  message: string;
  retryAfterSeconds?: number;
  statusCode?: number;
}

export interface TokenError {
  kind: 'no_refresh_token' | 'refresh_failed' | 'network_error';
  message: string;
  statusCode?: number;
  body?: string;
}

export function makeApiError(
  kind: ApiError['kind'],
  message: string,
  extra?: Partial<ApiError>,
): ApiError {
  return { kind, message, ...extra };
}

export function makeTokenError(
  kind: TokenError['kind'],
  message: string,
  extra?: Partial<TokenError>,
): TokenError {
  return { kind, message, ...extra };
}
