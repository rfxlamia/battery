import { describe, expect, it } from 'vitest';
import { formatResetTime, formatDuration, formatUpdatedAt } from '../lib/time-format.js';

describe('formatResetTime', () => {
  it('returns null when resetsAt is null', () => {
    expect(formatResetTime(null, new Date())).toBeNull();
  });

  it('returns null when resetsAt is in the past', () => {
    expect(
      formatResetTime('2026-03-17T00:00:00.000Z', new Date('2026-03-17T01:00:00.000Z')),
    ).toBeNull();
  });

  it('returns hours and minutes for future reset', () => {
    expect(
      formatResetTime('2026-03-17T01:18:00.000Z', new Date('2026-03-17T00:00:00.000Z')),
    ).toBe('1h 18m');
  });

  it('returns minutes only when less than 1 hour', () => {
    expect(
      formatResetTime('2026-03-17T00:45:00.000Z', new Date('2026-03-17T00:00:00.000Z')),
    ).toBe('45m');
  });
});

describe('formatDuration', () => {
  it('formats zero minutes as 0m', () => {
    expect(formatDuration(0)).toBe('0m');
  });

  it('formats 90 minutes as 1h 30m', () => {
    expect(formatDuration(90)).toBe('1h 30m');
  });

  it('formats 59 minutes as 59m', () => {
    expect(formatDuration(59)).toBe('59m');
  });
});

describe('formatUpdatedAt', () => {
  it('returns "just now" for very recent update', () => {
    expect(
      formatUpdatedAt('2026-03-17T00:00:00.000Z', new Date('2026-03-17T00:00:05.000Z')),
    ).toBe('just now');
  });

  it('returns seconds ago for recent update', () => {
    expect(
      formatUpdatedAt('2026-03-17T00:00:00.000Z', new Date('2026-03-17T00:00:30.000Z')),
    ).toBe('30s ago');
  });

  it('returns minutes ago', () => {
    expect(
      formatUpdatedAt('2026-03-17T00:00:00.000Z', new Date('2026-03-17T00:05:00.000Z')),
    ).toBe('5m ago');
  });

  it('returns hours ago', () => {
    expect(
      formatUpdatedAt('2026-03-17T00:00:00.000Z', new Date('2026-03-17T02:00:00.000Z')),
    ).toBe('2h ago');
  });

  it('returns "unknown" for null input', () => {
    expect(formatUpdatedAt(null, new Date())).toBe('unknown');
  });

  it('returns "unknown" for invalid date string', () => {
    expect(formatUpdatedAt('not-a-date', new Date())).toBe('unknown');
  });
});
