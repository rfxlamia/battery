import { fileURLToPath } from 'node:url';
import { pollOnceWithMeta } from './poll-once.js';
import type { BatteryState } from '../contracts/index.js';

const POLL_INTERVAL_ACTIVE_MS = 60_000;
const POLL_INTERVAL_IDLE_MS = 300_000;

export interface TickResult {
  wroteState: true;
  status: BatteryState['status'];
}

interface TickDeps {
  fetchImpl: typeof fetch;
  now: number;
  homeDir: string;
}

/**
 * Run a single poll-and-write cycle. Always writes state; returns summary.
 */
export async function runLoopTick(deps: TickDeps): Promise<TickResult> {
  const { state } = await pollOnceWithMeta(deps);
  return { wroteState: true, status: state.status };
}

export function getPollingIntervalMs(sessionActive: boolean): number {
  return sessionActive ? POLL_INTERVAL_ACTIVE_MS : POLL_INTERVAL_IDLE_MS;
}

export function getEffectiveInterval(
  currentInterval: number,
  consecutiveRateLimits: number,
  retryAfterSeconds?: number,
): number {
  if (consecutiveRateLimits <= 0) return currentInterval;
  const backoff = POLL_INTERVAL_ACTIVE_MS * 2 ** (consecutiveRateLimits - 1);
  const cappedBackoff = Math.min(backoff, 600_000);
  if (retryAfterSeconds === undefined) return cappedBackoff;
  return Math.max(cappedBackoff, retryAfterSeconds * 1000);
}

/**
 * Returns the node command to launch the core from its compiled location.
 * Reflects the development/compiled source path — not the installed systemd
 * path (%h/.local/share/battery/...). Useful for dev tooling and diagnostics.
 */
export function getServiceCommand(): string {
  const mainPath = fileURLToPath(new URL('../main.js', import.meta.url));
  return `node ${mainPath}`;
}

/**
 * Long-running loop for systemd --user service.
 * Polls on an interval that adapts to session activity.
 */
export async function runLoop(homeDir: string): Promise<never> {
  let consecutiveErrors = 0;
  let consecutiveRateLimits = 0;

  // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
  while (true) {
    let currentInterval = POLL_INTERVAL_IDLE_MS;
    let retryAfterSeconds;
    try {
      const now = Date.now();
      const { rateLimited, retryAfterSeconds: nextRetryAfterSeconds, sessionActive } =
        await pollOnceWithMeta({ fetchImpl: fetch, now, homeDir });
      consecutiveErrors = 0;
      currentInterval = getPollingIntervalMs(sessionActive);
      consecutiveRateLimits = rateLimited ? consecutiveRateLimits + 1 : 0;
      retryAfterSeconds = nextRetryAfterSeconds;
    } catch (err) {
      consecutiveErrors += 1;
      console.error(`Battery core poll error (${consecutiveErrors}):`, err);
    }

    const intervalMs = getEffectiveInterval(currentInterval, consecutiveRateLimits, retryAfterSeconds);
    await sleep(intervalMs);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
