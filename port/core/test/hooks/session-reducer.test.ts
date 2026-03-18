import { describe, expect, it } from 'vitest';
import { reduceSessionState, type HookEvent } from '../../src/hooks/session-reducer.js';

// Helpers
const t = (iso: string) => new Date(iso).getTime();

// Fixture events from session-start-stop.jsonl
const startStopEvents: HookEvent[] = [
  { event: 'SessionStart', timestamp: '2026-03-17T08:00:00Z', sessionId: 'abc123' },
  { event: 'PostToolUse', timestamp: '2026-03-17T08:01:00Z', sessionId: 'abc123', tool: 'Read' },
  { event: 'PostToolUse', timestamp: '2026-03-17T08:04:30Z', sessionId: 'abc123', tool: 'Write' },
  { event: 'SessionEnd', timestamp: '2026-03-17T08:10:00Z', sessionId: 'abc123' },
];

// Active session — recently started, no end
const activeEvents: HookEvent[] = [
  { event: 'SessionStart', timestamp: '2026-03-17T09:00:00Z', sessionId: 'def456' },
  { event: 'PostToolUse', timestamp: '2026-03-17T09:02:00Z', sessionId: 'def456', tool: 'Bash' },
  { event: 'PostToolUse', timestamp: '2026-03-17T09:03:00Z', sessionId: 'def456', tool: 'Read' },
];

// Idle timeout — last activity was 6+ minutes ago
const idleEvents: HookEvent[] = [
  { event: 'SessionStart', timestamp: '2026-03-17T09:00:00Z', sessionId: 'def456' },
  { event: 'PostToolUse', timestamp: '2026-03-17T09:03:00Z', sessionId: 'def456', tool: 'Read' },
];

describe('reduceSessionState', () => {
  it('returns inactive state after SessionEnd', () => {
    const now = t('2026-03-17T08:15:00Z');
    const result = reduceSessionState(startStopEvents, now);
    expect(result).toEqual({ isActive: false, currentSessionId: null });
  });

  it('returns active state for recent session with no end', () => {
    // now = 1 minute after last activity (09:04), well within 5-min timeout
    const now = t('2026-03-17T09:04:00Z');
    const result = reduceSessionState(activeEvents, now);
    expect(result.isActive).toBe(true);
    expect(result.currentSessionId).toBe('def456');
  });

  it('returns inactive when last activity was more than 300 seconds ago', () => {
    // now = 6 minutes after last activity (09:03)
    const now = t('2026-03-17T09:09:00Z');
    const result = reduceSessionState(idleEvents, now);
    expect(result).toEqual({ isActive: false, currentSessionId: null });
  });

  it('returns inactive for empty events', () => {
    const now = Date.now();
    const result = reduceSessionState([], now);
    expect(result).toEqual({ isActive: false, currentSessionId: null });
  });

  it('activates on PostToolUse even without prior SessionStart', () => {
    const events: HookEvent[] = [
      { event: 'PostToolUse', timestamp: '2026-03-17T09:03:00Z', sessionId: 'xyz', tool: 'Read' },
    ];
    const now = t('2026-03-17T09:04:00Z');
    const result = reduceSessionState(events, now);
    expect(result.isActive).toBe(true);
  });

  it('SessionEnd takes precedence over later PostToolUse from same session', () => {
    const events: HookEvent[] = [
      { event: 'SessionStart', timestamp: '2026-03-17T08:00:00Z', sessionId: 's1' },
      { event: 'PostToolUse', timestamp: '2026-03-17T08:05:00Z', sessionId: 's1', tool: 'Read' },
      { event: 'SessionEnd', timestamp: '2026-03-17T08:10:00Z', sessionId: 's1' },
    ];
    const now = t('2026-03-17T08:11:00Z');
    const result = reduceSessionState(events, now);
    expect(result.isActive).toBe(false);
  });
});
