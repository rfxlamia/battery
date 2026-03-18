import { fileURLToPath } from 'node:url';
import { pollOnce } from './poll-once.js';
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
  const state = await pollOnce(deps);
  return { wroteState: true, status: state.status };
}

/**
 * Returns the shell command used to launch the core (for use in systemd unit).
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

  // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
  while (true) {
    let intervalMs = POLL_INTERVAL_IDLE_MS;
    try {
      const now = Date.now();
      const state = await pollOnce({ fetchImpl: fetch, now, homeDir });
      consecutiveErrors = 0;
      intervalMs = state.session?.isActive ? POLL_INTERVAL_ACTIVE_MS : POLL_INTERVAL_IDLE_MS;
    } catch (err) {
      consecutiveErrors += 1;
      console.error(`Battery core poll error (${consecutiveErrors}):`, err);
    }

    await sleep(intervalMs);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
