import { describe, expect, it } from 'vitest';
import { formatResetTime, formatDuration } from '../lib/time-format.js';

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
