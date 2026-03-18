import { readFile, lstat, writeFile, mkdir, chmod } from 'node:fs/promises';
import { join } from 'node:path';
import type { HookEvent } from './session-reducer.js';

const MAX_LINE_BYTES = 4096;
const MAX_RECENT_LINES = 20;
const SESSION_ID_MAX_LEN = 128;
const TOOL_MAX_LEN = 256;
const STALENESS_THRESHOLD_SECONDS = 3600;

/**
 * Read the last N lines of the events file, applying safety rules from Swift parity:
 * - Refuse to open if the file is a symlink.
 * - Create the .battery directory (0700) and events.jsonl (0600) if missing.
 * - Silently drop lines over MAX_LINE_BYTES.
 * - Silently drop events with |timestamp - now| >= 3600s.
 * - Truncate sessionId/tool fields to max lengths.
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

    events.push({
      event: parsed.event,
      timestamp: parsed.timestamp,
      sessionId: parsed.sessionId
        ? String(parsed.sessionId).slice(0, SESSION_ID_MAX_LEN)
        : undefined,
      tool: parsed.tool ? String(parsed.tool).slice(0, TOOL_MAX_LEN) : undefined,
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
