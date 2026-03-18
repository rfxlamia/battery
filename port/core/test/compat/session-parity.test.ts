import { describe, expect, it } from 'vitest';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadHookFixture, loadExpected } from './compat-test-harness.js';
import { reduceSessionState, type SessionState } from '../../src/hooks/session-reducer.js';
import { readRecentEvents } from '../../src/hooks/read-events.js';

describe('session parity', () => {
  it('matches the expected active-session result from the Swift fixture (start-stop)', async () => {
    const fixture = await loadHookFixture('session-start-stop.jsonl');
    const expected = await loadExpected<SessionState>('session/start-stop.expected.json');
    const state = reduceSessionState(fixture.events, fixture.now);

    expect(state).toMatchObject(expected);
  });

  it('detects idle timeout from the Swift fixture (idle-timeout)', async () => {
    const fixture = await loadHookFixture('idle-timeout.jsonl');
    const expected = await loadExpected<SessionState>('session/idle-timeout.expected.json');
    const state = reduceSessionState(fixture.events, fixture.now);

    expect(state).toMatchObject(expected);
  });

  it('treats stop event identically to PostToolUse', async () => {
    const fixture = await loadHookFixture('stop-event.jsonl');
    const state = reduceSessionState(fixture.events, fixture.now);

    expect(state.isActive).toBe(false);
    expect(state.currentSessionId).toBeNull();
  });

  it('reports active when session started recently and no end event', async () => {
    const nowMs = new Date('2026-03-17T08:02:00Z').getTime();
    const events = [
      { event: 'SessionStart', timestamp: '2026-03-17T08:00:00Z', sessionId: 'sess-1' },
      { event: 'PostToolUse', timestamp: '2026-03-17T08:01:00Z', sessionId: 'sess-1', tool: 'Read' },
    ];
    const state = reduceSessionState(events, nowMs);

    expect(state.isActive).toBe(true);
    expect(state.currentSessionId).toBe('sess-1');
  });

  it('ignores malformed JSON lines in events file', async () => {
    const expected = await loadExpected<SessionState>('session/malformed-line-ignored.expected.json');
    const nowMs = new Date('2026-03-17T09:00:00Z').getTime();

    const homeDir = await mkdtemp(join(tmpdir(), 'battery-malformed-'));
    await mkdir(join(homeDir, '.battery'), { recursive: true });
    await writeFile(
      join(homeDir, '.battery', 'events.jsonl'),
      [
        '{"event":"SessionStart","timestamp":"2026-03-17T08:00:00Z","sessionId":"s1"}',
        'THIS IS NOT JSON',
        '{"event":"SessionEnd","timestamp":"2026-03-17T08:05:00Z","sessionId":"s1"}',
      ].join('\n'),
      { mode: 0o600 },
    );

    const events = await readRecentEvents(homeDir, nowMs);
    const state = reduceSessionState(events, nowMs);

    expect(state).toMatchObject(expected);
  });

  it('ignores oversized lines in events file', async () => {
    const expected = await loadExpected<SessionState>('session/oversized-line-ignored.expected.json');
    const nowMs = new Date('2026-03-17T09:00:00Z').getTime();

    const homeDir = await mkdtemp(join(tmpdir(), 'battery-oversized-'));
    await mkdir(join(homeDir, '.battery'), { recursive: true });

    // Create a line > 4096 bytes
    const oversizedTool = 'X'.repeat(5000);
    await writeFile(
      join(homeDir, '.battery', 'events.jsonl'),
      [
        '{"event":"SessionStart","timestamp":"2026-03-17T08:00:00Z","sessionId":"s1"}',
        JSON.stringify({ event: 'PostToolUse', timestamp: '2026-03-17T08:01:00Z', sessionId: 's1', tool: oversizedTool }),
        '{"event":"SessionEnd","timestamp":"2026-03-17T08:05:00Z","sessionId":"s1"}',
      ].join('\n'),
      { mode: 0o600 },
    );

    const events = await readRecentEvents(homeDir, nowMs);
    const state = reduceSessionState(events, nowMs);

    expect(state).toMatchObject(expected);
  });

  it('activates session from PostToolUse without prior SessionStart (startup replay)', async () => {
    const expected = await loadExpected<SessionState>('session/startup-replay.expected.json');
    // PostToolUse 2 minutes ago, no SessionStart — reducer infers active session
    const nowMs = new Date('2026-03-17T08:03:00Z').getTime();
    const events = [
      { event: 'PostToolUse', timestamp: '2026-03-17T08:01:00Z', tool: 'Bash' },
    ];
    const state = reduceSessionState(events, nowMs);

    expect(state.isActive).toBe(expected.isActive);
    // currentSessionId comes from the synthesized SessionStart which has no sessionId
    expect(state.currentSessionId).toBeNull();
  });
});
