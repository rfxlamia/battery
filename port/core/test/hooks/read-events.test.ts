import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, writeFile, mkdir, symlink, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readRecentEvents } from '../../src/hooks/read-events.js';

// "now" used throughout — events within this must be within 3600s
const NOW_ISO = '2026-03-17T09:00:00Z';
const nowMs = new Date(NOW_ISO).getTime();

// Helper: timestamp within the 1-hour staleness window
const ts = (offsetSeconds: number) =>
  new Date(nowMs + offsetSeconds * 1000).toISOString();

describe('readRecentEvents', () => {
  let homeDir: string;
  let eventsPath: string;

  beforeEach(async () => {
    homeDir = await mkdtemp(join(tmpdir(), 'battery-events-test-'));
    await mkdir(join(homeDir, '.battery'), { recursive: true });
    eventsPath = join(homeDir, '.battery', 'events.jsonl');
  });

  it('returns empty array and creates events.jsonl when file is missing', async () => {
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toEqual([]);
    // File should now exist
    const s = await stat(eventsPath);
    expect(s.isFile()).toBe(true);
  });

  it('returns empty array when events file is a symlink (symlink rejection)', async () => {
    const realFile = join(homeDir, 'real-events.jsonl');
    await writeFile(realFile, `{"event":"SessionStart","timestamp":"${ts(0)}","sessionId":"s1"}\n`);
    await symlink(realFile, eventsPath);
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toEqual([]);
  });

  it('parses valid events correctly', async () => {
    await writeFile(eventsPath, [
      `{"event":"SessionStart","timestamp":"${ts(0)}","sessionId":"abc"}`,
      `{"event":"PostToolUse","timestamp":"${ts(30)}","sessionId":"abc","tool":"Read"}`,
    ].join('\n') + '\n');
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toHaveLength(2);
    expect(events[0]).toMatchObject({ event: 'SessionStart', sessionId: 'abc' });
    expect(events[1]).toMatchObject({ event: 'PostToolUse', tool: 'Read' });
  });

  it('silently drops lines exceeding 4096 bytes', async () => {
    const oversized = `{"event":"SessionStart","timestamp":"${ts(0)}","sessionId":"${'x'.repeat(4100)}"}`;
    const normal = `{"event":"PostToolUse","timestamp":"${ts(30)}","sessionId":"abc","tool":"Bash"}`;
    await writeFile(eventsPath, [oversized, normal].join('\n') + '\n');
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toHaveLength(1);
    expect(events[0]?.event).toBe('PostToolUse');
  });

  it('silently drops stale events (|delta| >= 3600s)', async () => {
    const staleOld = `{"event":"SessionStart","timestamp":"${ts(-3600)}","sessionId":"old"}`;
    const staleFuture = `{"event":"SessionStart","timestamp":"${ts(3600)}","sessionId":"future"}`;
    const fresh = `{"event":"PostToolUse","timestamp":"${ts(60)}","sessionId":"ok","tool":"Read"}`;
    await writeFile(eventsPath, [staleOld, staleFuture, fresh].join('\n') + '\n');
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toHaveLength(1);
    expect(events[0]?.sessionId).toBe('ok');
  });

  it('silently drops malformed JSON lines', async () => {
    await writeFile(eventsPath, [
      `{"event":"SessionStart","timestamp":"${ts(0)}","sessionId":"s1"}`,
      `not valid json`,
      `{"broken":`,
      `{"event":"PostToolUse","timestamp":"${ts(10)}","sessionId":"s1","tool":"Read"}`,
    ].join('\n') + '\n');
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toHaveLength(2);
  });

  it('only returns the last 20 lines from a longer file', async () => {
    const lines = Array.from({ length: 30 }, (_, i) =>
      `{"event":"PostToolUse","timestamp":"${ts(i)}","sessionId":"s","tool":"Read"}`,
    );
    await writeFile(eventsPath, lines.join('\n') + '\n');
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toHaveLength(20);
    // The last 20 have offsets 10–29
    expect(events[0]).toMatchObject({ timestamp: ts(10) });
    expect(events[19]).toMatchObject({ timestamp: ts(29) });
  });

  it('drops sessionId values beyond 128 characters', async () => {
    const longId = 'a'.repeat(200);
    await writeFile(eventsPath, `{"event":"SessionStart","timestamp":"${ts(0)}","sessionId":"${longId}"}\n`);
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toEqual([]);
  });

  it('drops tool names beyond 256 characters', async () => {
    const longTool = 'T'.repeat(300);
    await writeFile(eventsPath, `{"event":"PostToolUse","timestamp":"${ts(0)}","sessionId":"s","tool":"${longTool}"}\n`);
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toEqual([]);
  });

  it('omits sessionId and tool keys entirely when absent (exactOptionalPropertyTypes)', async () => {
    await writeFile(eventsPath, `{"event":"SessionStart","timestamp":"${ts(0)}"}\n`);
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events[0]).not.toHaveProperty('sessionId');
    expect(events[0]).not.toHaveProperty('tool');
  });

  it('drops events beyond the 50-per-second admission limit', async () => {
    const lines = Array.from({ length: 55 }, (_, i) =>
      `{"event":"PostToolUse","timestamp":"${ts(0)}","sessionId":"s${i}","tool":"Read"}`,
    );
    await writeFile(eventsPath, lines.join('\n') + '\n');
    const events = await readRecentEvents(homeDir, nowMs);
    expect(events).toHaveLength(20);
  });
});
