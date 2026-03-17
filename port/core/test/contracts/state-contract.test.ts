import { describe, expect, it } from 'vitest';
import { batteryStateSchema } from '../../src/contracts/index.js';

describe('batteryStateSchema', () => {
  it('accepts the minimal disconnected state', () => {
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'login_required',
      updatedAt: '2026-03-17T00:00:00.000Z',
      freshness: {
        staleAfterSeconds: 360,
      },
    });

    expect(result.success).toBe(true);
  });

  it('accepts the MVP ok state with weekly and freshness metadata', () => {
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'ok',
      updatedAt: '2026-03-17T00:00:00.000Z',
      account: {
        id: 'acct-1',
        name: 'Primary',
        planTier: 'pro',
        isSelected: true,
      },
      session: {
        utilization: 0.32,
        resetsAt: '2026-03-17T05:00:00.000Z',
        isActive: true,
      },
      weekly: {
        utilization: 0.18,
        resetsAt: '2026-03-24T00:00:00.000Z',
      },
      freshness: {
        staleAfterSeconds: 360,
      },
    });

    expect(result.success).toBe(true);
  });

  it('rejects an unknown status', () => {
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'mystery',
      updatedAt: '2026-03-17T00:00:00.000Z',
      freshness: {
        staleAfterSeconds: 360,
      },
    });

    expect(result.success).toBe(false);
  });

  it('rejects an invalid timestamp', () => {
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'login_required',
      updatedAt: 'not-a-date',
      freshness: {
        staleAfterSeconds: 360,
      },
    });

    expect(result.success).toBe(false);
  });
});
