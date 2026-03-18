import { fileURLToPath } from 'node:url';
import { pollOnceWithMeta } from './poll-once.js';
import type { BatteryState } from '../contracts/index.js';
import type { PollOutcome } from './poll-once.js';

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

export interface RunLoopState {
  currentInterval: number;
  consecutiveErrors: number;
  consecutiveRateLimits: number;
}

interface StepDeps extends TickDeps {
  pollOnceWithMetaImpl?: (deps: TickDeps) => Promise<PollOutcome>;
  logError?: (message: string, error: unknown) => void;
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

export function getNextPollingInterval(
  currentInterval: number,
  sessionActive?: boolean,
): number {
  if (sessionActive === undefined) return currentInterval;
  return getPollingIntervalMs(sessionActive);
}

export function createInitialRunLoopState(): RunLoopState {
  return {
    currentInterval: POLL_INTERVAL_ACTIVE_MS,
    consecutiveErrors: 0,
    consecutiveRateLimits: 0,
  };
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

export async function runLoopStep(
  loopState: RunLoopState,
  deps: StepDeps,
): Promise<{ loopState: RunLoopState; sleepMs: number }> {
  const pollImpl = deps.pollOnceWithMetaImpl ?? pollOnceWithMeta;
  const logError = deps.logError ?? ((message: string, error: unknown) => console.error(message, error));
  let nextLoopState = loopState;
  let retryAfterSeconds;

  try {
    const { rateLimited, retryAfterSeconds: nextRetryAfterSeconds, sessionActive } = await pollImpl(deps);
    nextLoopState = {
      currentInterval: getNextPollingInterval(loopState.currentInterval, sessionActive),
      consecutiveErrors: 0,
      consecutiveRateLimits: rateLimited ? loopState.consecutiveRateLimits + 1 : 0,
    };
    retryAfterSeconds = nextRetryAfterSeconds;
  } catch (err) {
    const consecutiveErrors = loopState.consecutiveErrors + 1;
    nextLoopState = { ...loopState, consecutiveErrors };
    logError(`Battery core poll error (${consecutiveErrors}):`, err);
  }

  return {
    loopState: nextLoopState,
    sleepMs: getEffectiveInterval(
      nextLoopState.currentInterval,
      nextLoopState.consecutiveRateLimits,
      retryAfterSeconds,
    ),
  };
}

/**
 * Long-running loop for systemd --user service.
 * Polls on an interval that adapts to session activity.
 */
export async function runLoop(homeDir: string): Promise<never> {
  let loopState = createInitialRunLoopState();

  // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
  while (true) {
    const step = await runLoopStep(loopState, { fetchImpl: fetch, now: Date.now(), homeDir });
    loopState = step.loopState;
    await sleep(step.sleepMs);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
