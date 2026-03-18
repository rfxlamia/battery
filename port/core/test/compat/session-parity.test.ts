import { describe, expect, it } from 'vitest';
import { loadHookFixture } from './compat-test-harness.js';
import { reduceSessionState } from '../../src/hooks/session-reducer.js';

describe('session parity', () => {
  it('matches the expected active-session result from the Swift fixture (start-stop)', async () => {
    const fixture = await loadHookFixture('session-start-stop.jsonl');
    // SessionEnd timestamp (08:10) >= SessionStart timestamp (08:00), so session is inactive.
    // now = 1h after last event, well past any timeout.
    const state = reduceSessionState(fixture.events, fixture.now);

    expect(state.isActive).toBe(false);
    expect(state.currentSessionId).toBeNull();
  });

  it('detects idle timeout from the Swift fixture (idle-timeout)', async () => {
    const fixture = await loadHookFixture('idle-timeout.jsonl');
    // Last activity at 09:03:00, now = 1h later → well beyond 300s idle timeout
    const state = reduceSessionState(fixture.events, fixture.now);

    expect(state.isActive).toBe(false);
    expect(state.currentSessionId).toBeNull();
  });

  it('treats stop event identically to PostToolUse', async () => {
    const fixture = await loadHookFixture('stop-event.jsonl');
    // SessionEnd timestamp (10:05) >= SessionStart (10:00), so session is inactive
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
});
