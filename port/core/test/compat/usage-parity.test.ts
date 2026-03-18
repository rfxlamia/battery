import { describe, expect, it } from 'vitest';
import { loadExpected } from './compat-test-harness.js';
import { buildOkState } from '../../src/runtime/build-state.js';
import { batteryStateSchema } from '../../src/contracts/index.js';

describe('usage parity', () => {
  const account = { id: 'acct-1', name: 'Alice', planTier: 'pro' as const };
  const inactiveSession = { isActive: false, currentSessionId: null };
  const activeSession = { isActive: true, currentSessionId: 'sess-1' };
  const now = new Date('2026-03-17T09:00:00Z').getTime();

  it('normalizes sample-200 usage to contract-compatible 0.0–1.0 range', async () => {
    const expected = await loadExpected<{
      session: { utilization: number; resetsAt: string | null };
      weekly: { utilization: number; resetsAt: string | null };
    }>('usage/sample-200.expected.json');

    // Simulate the raw API response (percent scale)
    const usage = {
      fiveHour: { utilization: 42.5, resetsAt: '2026-03-17T13:00:00Z' },
      sevenDay: { utilization: 61.2, resetsAt: '2026-03-23T00:00:00Z' },
    };

    const state = buildOkState(account, usage, inactiveSession, now);

    expect(state.session?.utilization).toBeCloseTo(expected.session.utilization, 5);
    expect(state.session?.resetsAt).toBe(expected.session.resetsAt);
    expect(state.weekly?.utilization).toBeCloseTo(expected.weekly.utilization, 5);
    expect(state.weekly?.resetsAt).toBe(expected.weekly.resetsAt);

    // Must validate against the shared contract
    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });

  it('preserves session resetsAt from the five_hour window', () => {
    const usage = {
      fiveHour: { utilization: 10.0, resetsAt: '2026-03-17T14:00:00Z' },
      sevenDay: { utilization: 20.0, resetsAt: '2026-03-24T00:00:00Z' },
    };

    const state = buildOkState(account, usage, inactiveSession, now);

    expect(state.session?.resetsAt).toBe('2026-03-17T14:00:00Z');
    expect(state.weekly?.resetsAt).toBe('2026-03-24T00:00:00Z');
  });

  it('sets session utilization to 0 when five_hour is null', () => {
    const usage = {
      fiveHour: null,
      sevenDay: { utilization: 55.0, resetsAt: '2026-03-23T00:00:00Z' },
    };

    const state = buildOkState(account, usage, inactiveSession, now);

    expect(state.session?.utilization).toBe(0);
    expect(state.session?.resetsAt).toBeNull();
    expect(state.weekly?.utilization).toBeCloseTo(0.55, 5);
  });

  it('preserves plan tier in the contract output', () => {
    const proAccount = { id: 'a1', name: 'Bob', planTier: 'pro' as const };
    const usage = {
      fiveHour: { utilization: 5.0, resetsAt: '2026-03-17T14:00:00Z' },
      sevenDay: { utilization: 10.0, resetsAt: '2026-03-24T00:00:00Z' },
    };

    const state = buildOkState(proAccount, usage, inactiveSession, now);
    expect(state.account?.planTier).toBe('pro');
  });

  it('uses 60s freshness when session is active, 300s when idle', () => {
    const usage = {
      fiveHour: { utilization: 5.0, resetsAt: '2026-03-17T14:00:00Z' },
      sevenDay: { utilization: 10.0, resetsAt: '2026-03-24T00:00:00Z' },
    };

    const activeState = buildOkState(account, usage, activeSession, now);
    expect(activeState.freshness.staleAfterSeconds).toBe(60);

    const idleState = buildOkState(account, usage, inactiveSession, now);
    expect(idleState.freshness.staleAfterSeconds).toBe(300);
  });
});
