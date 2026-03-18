import { makeApiError, type ApiError } from './api-errors.js';
import { ANTHROPIC_API_BASE_URL } from '../config/env.js';

const USAGE_TIMEOUT_MS = 15_000;

export interface UsageWindow {
  utilization: number;
  resetsAt: string | null;
}

export interface UsageResponse {
  fiveHour: UsageWindow | null;
  sevenDay: UsageWindow;
}

interface RawWindow {
  utilization: number;
  resets_at: string;
}

interface RawUsageBody {
  five_hour?: RawWindow;
  seven_day: RawWindow;
}

export async function fetchUsage(
  fetchImpl: typeof fetch,
  accessToken: string,
  baseUrl: string = ANTHROPIC_API_BASE_URL,
): Promise<UsageResponse> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), USAGE_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetchImpl(`${baseUrl}/v1/usage`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'anthropic-version': '2023-06-01',
      },
      signal: controller.signal,
    });
  } catch (err) {
    clearTimeout(timeout);
    throw makeApiError('network_error', `Network error fetching usage: ${String(err)}`);
  } finally {
    clearTimeout(timeout);
  }

  if (response.status === 401) {
    throw makeApiError('unauthorized', 'Unauthorized — token may be expired') as ApiError;
  }

  if (response.status === 429) {
    const retryAfterHeader = response.headers.get('Retry-After');
    const retryAfterSeconds = retryAfterHeader ? parseInt(retryAfterHeader, 10) : undefined;
    throw makeApiError('rate_limited', 'Rate limit exceeded', { retryAfterSeconds });
  }

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw makeApiError('server_error', `Server error ${response.status}: ${body}`, {
      statusCode: response.status,
    });
  }

  let raw: RawUsageBody;
  try {
    raw = (await response.json()) as RawUsageBody;
  } catch (err) {
    throw makeApiError('decoding_error', `Failed to decode usage response: ${String(err)}`);
  }

  return {
    fiveHour: raw.five_hour
      ? { utilization: raw.five_hour.utilization, resetsAt: raw.five_hour.resets_at }
      : null,
    sevenDay: {
      utilization: raw.seven_day.utilization,
      resetsAt: raw.seven_day.resets_at,
    },
  };
}
