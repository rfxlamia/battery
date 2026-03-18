import { describe, expect, it } from 'vitest';
import { buildPopupRows } from '../lib/popup-view.js';

describe('buildPopupRows', () => {
  const okState = {
    version: 1,
    status: 'ok',
    updatedAt: '2026-03-17T00:00:00.000Z',
    account: { id: 'a1', name: 'Alice', planTier: 'pro', isSelected: true },
    session: { utilization: 0.42, resetsAt: '2026-03-17T01:18:00.000Z', isActive: true },
    weekly: { utilization: 0.31, resetsAt: '2026-03-21T00:00:00.000Z' },
    freshness: { staleAfterSeconds: 360 },
  };

  it('includes account name for ok state', () => {
    const rows = buildPopupRows(okState, new Date('2026-03-17T00:00:00.000Z'));
    expect(rows.some((r) => r.value?.includes('Alice'))).toBe(true);
  });

  it('includes plan tier', () => {
    const rows = buildPopupRows(okState, new Date('2026-03-17T00:00:00.000Z'));
    expect(rows.some((r) => r.value?.toLowerCase().includes('pro'))).toBe(true);
  });

  it('includes session utilization percentage', () => {
    const rows = buildPopupRows(okState, new Date('2026-03-17T00:00:00.000Z'));
    expect(rows.some((r) => r.value?.includes('42%'))).toBe(true);
  });

  it('includes weekly utilization percentage', () => {
    const rows = buildPopupRows(okState, new Date('2026-03-17T00:00:00.000Z'));
    expect(rows.some((r) => r.value?.includes('31%'))).toBe(true);
  });

  it('returns login_required message for login_required state', () => {
    const rows = buildPopupRows({ status: 'login_required', freshness: { staleAfterSeconds: 300 } });
    expect(rows.some((r) => r.message?.toLowerCase().includes('sign in'))).toBe(true);
  });

  it('returns error message for error state', () => {
    const rows = buildPopupRows({
      status: 'error',
      error: { code: 'rate_limited', message: 'Too many requests' },
      freshness: { staleAfterSeconds: 300 },
    });
    expect(rows.some((r) => r.message?.toLowerCase().includes('error'))).toBe(true);
  });

  it('returns stale notice when state is stale', () => {
    const staleState = {
      status: 'ok',
      updatedAt: '2026-03-17T00:00:00.000Z',
      account: { id: 'a1', name: 'Alice', planTier: 'pro', isSelected: true },
      session: { utilization: 0.5, resetsAt: null, isActive: false },
      freshness: { staleAfterSeconds: 300 },
    };
    const rows = buildPopupRows(staleState, new Date('2026-03-17T00:20:00.000Z'));
    expect(rows.some((r) => r.stale === true)).toBe(true);
  });

  it('returns safe fallback for null state', () => {
    const rows = buildPopupRows(null);
    expect(Array.isArray(rows)).toBe(true);
    expect(rows.length).toBeGreaterThan(0);
  });
});
