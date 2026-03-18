import { describe, expect, it } from 'vitest';
import { loadExpected } from './compat-test-harness.js';
import { buildOkState } from '../../src/runtime/build-state.js';
import { batteryStateSchema } from '../../src/contracts/index.js';

describe('usage parity', () => {
  const account = { id: 'acct-1', name: 'Alice', planTier: 'pro' as const };
  const inactiveSession = { isActive: false, currentSessionId: null };
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
});
