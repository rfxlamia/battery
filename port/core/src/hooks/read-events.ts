import { readFile, lstat, writeFile, mkdir, chmod } from 'node:fs/promises';
import { join } from 'node:path';
import type { HookEvent } from './session-reducer.js';

const MAX_LINE_BYTES = 4096;
const MAX_RECENT_LINES = 20;
const SESSION_ID_MAX_LEN = 128;
const TOOL_MAX_LEN = 256;
const STALENESS_THRESHOLD_SECONDS = 3600;
const MAX_EVENTS_PER_SECOND = 50;

/**
 * Read the last N lines of the events file, applying safety rules from Swift parity:
 * - Refuse to open if the file is a symlink.
 * - Create the .battery directory (0700) and events.jsonl (0600) if missing.
 * - Silently drop lines over MAX_LINE_BYTES.
 * - Silently drop events with |timestamp - now| >= 3600s.
 * - Drop events whose sessionId/tool exceed the Swift length limits.
 * - Drop events beyond the Swift 50 events/second admission limit.
 */
export async function readRecentEvents(homeDir: string, nowMs: number): Promise<HookEvent[]> {
  const batteryDir = join(homeDir, '.battery');
  const eventsPath = join(batteryDir, 'events.jsonl');

  // Ensure directory exists with restrictive permissions
  await mkdir(batteryDir, { recursive: true });
  try {
    await chmod(batteryDir, 0o700);
  } catch {
    // Best-effort; ignore if we lack permission
  }

  // Check for symlink
  try {
    const stat = await lstat(eventsPath);
    if (stat.isSymbolicLink()) {
      return [];
    }
  } catch {
    // File does not exist — create it
    await writeFile(eventsPath, '', { mode: 0o600 });
    return [];
  }

  let content: string;
  try {
    content = await readFile(eventsPath, 'utf8');
  } catch {
    return [];
  }

  const allLines = content.split('\n').filter((l) => l.trim().length > 0);
  const recentLines = allLines.slice(-MAX_RECENT_LINES);

  const events: HookEvent[] = [];
  const eventsPerSecond = new Map<number, number>();
  for (const line of recentLines) {
    // Drop lines over the byte limit
    if (Buffer.byteLength(line, 'utf8') > MAX_LINE_BYTES) continue;

    let parsed: unknown;
    try {
      parsed = JSON.parse(line);
    } catch {
      continue;
    }

    if (!isHookEventShape(parsed)) continue;

    // Drop stale events
    const eventMs = new Date(parsed.timestamp).getTime();
    if (isNaN(eventMs)) continue;
    if (Math.abs(nowMs - eventMs) / 1000 >= STALENESS_THRESHOLD_SECONDS) continue;
    if (parsed.sessionId && String(parsed.sessionId).length > SESSION_ID_MAX_LEN) continue;
    if (parsed.tool && String(parsed.tool).length > TOOL_MAX_LEN) continue;

    const secondBucket = Math.floor(eventMs / 1000);
    const currentCount = eventsPerSecond.get(secondBucket) ?? 0;
    if (currentCount >= MAX_EVENTS_PER_SECOND) continue;
    eventsPerSecond.set(secondBucket, currentCount + 1);

    events.push({
      event: parsed.event,
      timestamp: parsed.timestamp,
      ...(parsed.sessionId ? { sessionId: String(parsed.sessionId) } : {}),
      ...(parsed.tool ? { tool: String(parsed.tool) } : {}),
    });
  }

  return events;
}

function isHookEventShape(
  v: unknown,
): v is { event: string; timestamp: string; sessionId?: string; tool?: string } {
  return (
    typeof v === 'object' &&
    v !== null &&
    typeof (v as Record<string, unknown>)['event'] === 'string' &&
    typeof (v as Record<string, unknown>)['timestamp'] === 'string'
  );
}
