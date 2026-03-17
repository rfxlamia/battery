import { describe, expect, it } from 'vitest';
import { batteryStateSchema, errorSchema, weeklySchema } from '../../src/contracts/index.js';

describe('error state', () => {
  it('accepts a rate_limited error with retryAfterSeconds', () => {
    expect(batteryStateSchema.parse({
      version: 1,
      status: 'error',
      updatedAt: '2026-03-17T00:00:00.000Z',
      error: {
        kind: 'rate_limited',
        message: 'Rate limited',
        retryAfterSeconds: 30,
      },
      freshness: {
        staleAfterSeconds: 360,
      },
    })).toBeDefined();
  });

  it('rejects unknown error kinds', () => {
    const result = errorSchema.safeParse({
      kind: 'timeout',
      message: 'Timed out',
    });

    expect(result.success).toBe(false);
  });

  it('accepts an error without retryAfterSeconds', () => {
    const result = errorSchema.safeParse({
      kind: 'network_error',
      message: 'No connection',
    });

    expect(result.success).toBe(true);
  });
});

describe('weekly schema', () => {
  it('rejects weekly when resetsAt is not an ISO timestamp', () => {
    const result = weeklySchema.safeParse({
      utilization: 0.5,
      resetsAt: 'next-monday',
    });

    expect(result.success).toBe(false);
  });

  it('accepts weekly with null resetsAt', () => {
    const result = weeklySchema.safeParse({
      utilization: 0.5,
      resetsAt: null,
    });

    expect(result.success).toBe(true);
  });
});

describe('deferred parity fields', () => {
  it('allows opus, sonnet, and extraUsage to be absent in the MVP shape', () => {
    // These deferred fields are intentionally NOT part of the MVP contract.
    // The schema must accept their absence without error.
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'ok',
      updatedAt: '2026-03-17T00:00:00.000Z',
      account: {
        id: 'acct-1',
        name: 'Primary',
        planTier: 'pro',
        isSelected: true as const,
      },
      session: {
        utilization: 0.4,
        resetsAt: null,
        isActive: true,
      },
      weekly: {
        utilization: 0.2,
        resetsAt: null,
      },
      freshness: {
        staleAfterSeconds: 360,
      },
    });

    expect(result.success).toBe(true);
    if (result.success) {
      // Verify deferred fields are not present on the parsed output
      expect((result.data as Record<string, unknown>).opus).toBeUndefined();
      expect((result.data as Record<string, unknown>).sonnet).toBeUndefined();
      expect((result.data as Record<string, unknown>).extraUsage).toBeUndefined();
    }
  });
});
