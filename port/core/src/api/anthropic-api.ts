import { appendFile, chmod, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { makeApiError, type ApiError } from './api-errors.js';
import {
  ANTHROPIC_API_BASE_URL,
  ANTHROPIC_BETA_HEADER,
  BATTERY_USER_AGENT,
} from '../config/env.js';

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
    response = await fetchImpl(`${baseUrl}/api/oauth/usage`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'anthropic-beta': ANTHROPIC_BETA_HEADER,
        'User-Agent': BATTERY_USER_AGENT,
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
    throw makeApiError('unauthorized', 'Unauthorized — token may be expired');
  }

  if (response.status === 429) {
    const body = await response.text().catch(() => '');
    const retryAfterHeader = response.headers.get('Retry-After');
    const retryAfterSeconds = parseRetryAfterSeconds(retryAfterHeader);
    await logRateLimitDetails(response, body).catch(() => {});
    throw makeApiError(
      'rate_limited',
      'Rate limit exceeded',
      retryAfterSeconds !== undefined ? { retryAfterSeconds } : {},
    );
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

function parseRetryAfterSeconds(retryAfterHeader: string | null): number | undefined {
  if (!retryAfterHeader) return undefined;
  const parsed = Number.parseInt(retryAfterHeader, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : undefined;
}

async function logRateLimitDetails(response: Response, body: string): Promise<void> {
  const homeDir = process.env['HOME'];
  if (!homeDir) return;

  const batteryDir = join(homeDir, '.battery');
  const logPath = join(batteryDir, 'rate-limits.log');
  await mkdir(batteryDir, { recursive: true, mode: 0o700 });

  const timestamp = new Date().toISOString();
  const headerLines: string[] = [];
  for (const [key, value] of response.headers.entries()) {
    const lower = key.toLowerCase();
    if (lower.includes('ratelimit') || lower.includes('rate-limit') || lower === 'retry-after') {
      headerLines.push(`  ${key}: ${value}`);
    }
  }

  const lines = [
    `[${timestamp}] 429 Rate Limited`,
    ...headerLines,
    ...(body ? [`  Body: ${body}`] : []),
    '',
  ];

  await appendFile(logPath, `${lines.join('\n')}\n`, { encoding: 'utf8', mode: 0o600 });
  await chmod(logPath, 0o600);
}
