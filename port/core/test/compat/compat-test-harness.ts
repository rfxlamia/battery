import { readFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { HookEvent } from '../../src/hooks/session-reducer.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES_ROOT = join(__dirname, '..', '..', '..', '..', 'fixtures');

/**
 * Load a JSONL hook-event fixture file, filtering out documentation-only lines
 * (objects with no `event` key, e.g. `_note` lines).
 */
export async function loadHookFixture(
  relativePath: string,
): Promise<{ events: HookEvent[]; now: number }> {
  const filePath = join(FIXTURES_ROOT, 'examples', 'hook-events', relativePath);
  const raw = await readFile(filePath, 'utf-8');
  const events: HookEvent[] = [];
  let latestTimestamp = 0;

  for (const line of raw.trim().split('\n')) {
    if (!line.trim()) continue;
    const parsed = JSON.parse(line);
    if (!parsed.event) continue; // skip _note lines
    events.push(parsed as HookEvent);
    const ts = new Date(parsed.timestamp).getTime();
    if (ts > latestTimestamp) latestTimestamp = ts;
  }

  // Set "now" to 1 hour after the last event so tests can control timing
  const now = latestTimestamp + 3600 * 1000;
  return { events, now };
}

/**
 * Load a JSON fixture file for usage-api responses.
 */
export async function loadUsageFixture(relativePath: string): Promise<unknown> {
  const filePath = join(FIXTURES_ROOT, 'examples', 'usage-api', relativePath);
  const raw = await readFile(filePath, 'utf-8');
  return JSON.parse(raw);
}

/**
 * Load an expected-output JSON fixture from the compat directory.
 */
export async function loadExpected<T = unknown>(relativePath: string): Promise<T> {
  const filePath = join(FIXTURES_ROOT, 'compat', relativePath);
  const raw = await readFile(filePath, 'utf-8');
  return JSON.parse(raw) as T;
}
