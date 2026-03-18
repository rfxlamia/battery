import { describe, expect, it } from 'vitest';
import { getIndicatorLabel, getDisplayState } from '../lib/status-model.js';

describe('getIndicatorLabel', () => {
  it('renders login-required state', () => {
    expect(getIndicatorLabel({ status: 'login_required' })).toBe('Battery Sign in');
  });

  it('renders ok state from contract-shaped mock data', () => {
    expect(
      getIndicatorLabel(
        {
          status: 'ok',
          session: { utilization: 0.42, resetsAt: '2026-03-17T01:18:00.000Z', isActive: true },
          freshness: { staleAfterSeconds: 360 },
          updatedAt: '2026-03-17T00:00:00.000Z',
        },
        new Date('2026-03-17T00:00:00.000Z'),
      ),
    ).toContain('42%');
  });

  it('renders loading state', () => {
    expect(getIndicatorLabel({ status: 'loading' })).toBe('Battery …');
  });

  it('renders error state', () => {
    expect(getIndicatorLabel({ status: 'error' })).toBe('Battery Error');
  });

  it('renders stale when data is old', () => {
    const staleState = {
      status: 'ok',
      session: { utilization: 0.5, resetsAt: null, isActive: false },
      freshness: { staleAfterSeconds: 300 },
      updatedAt: '2026-03-17T00:00:00.000Z',
    };
    expect(
      getIndicatorLabel(staleState, new Date('2026-03-17T00:20:00.000Z')),
    ).toBe('Battery Stale');
  });

  it('renders stale when the local state file is missing', () => {
    expect(getIndicatorLabel({ _localStateStatus: 'missing' })).toBe('Battery Stale');
  });

  it('renders error when the local state file is invalid', () => {
    expect(getIndicatorLabel({ _localStateStatus: 'invalid' })).toBe('Battery Error');
  });

  it('renders reset time in label', () => {
    const label = getIndicatorLabel(
      {
        status: 'ok',
        session: { utilization: 0.42, resetsAt: '2026-03-17T01:18:00.000Z', isActive: true },
        freshness: { staleAfterSeconds: 3600 },
        updatedAt: '2026-03-17T00:00:00.000Z',
      },
      new Date('2026-03-17T00:00:00.000Z'),
    );
    expect(label).toContain('1h 18m');
  });
});

describe('getDisplayState', () => {
  it('returns stale kind when data is old', () => {
    const staleState = {
      status: 'ok',
      session: { utilization: 0.5, resetsAt: null, isActive: false },
      freshness: { staleAfterSeconds: 300 },
      updatedAt: '2026-03-17T00:00:00.000Z',
    };
    expect(getDisplayState(staleState, new Date('2026-03-17T00:20:00.000Z'))).toMatchObject({
      kind: 'stale',
    });
  });

  it('returns ok kind for fresh state', () => {
    expect(
      getDisplayState(
        {
          status: 'ok',
          freshness: { staleAfterSeconds: 3600 },
          updatedAt: '2026-03-17T00:00:00.000Z',
        },
        new Date('2026-03-17T00:00:00.000Z'),
      ),
    ).toMatchObject({ kind: 'ok' });
  });

  it('returns stale kind for missing local state', () => {
    expect(getDisplayState({ _localStateStatus: 'missing' })).toMatchObject({ kind: 'stale' });
  });
});
