import { describe, expect, expectTypeOf, it } from 'vitest';
import { batteryStateSchema } from '../../src/contracts/index.js';
import type { BatteryState } from '../../src/contracts/index.js';

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

describe('BatteryState type shape', () => {
  it('has required top-level fields', () => {
    expectTypeOf<BatteryState>().toHaveProperty('version');
    expectTypeOf<BatteryState>().toHaveProperty('status');
    expectTypeOf<BatteryState>().toHaveProperty('updatedAt');
    expectTypeOf<BatteryState>().toHaveProperty('freshness');
  });

  it('has optional domain fields', () => {
    expectTypeOf<BatteryState['account']>().toBeNullable();
    expectTypeOf<BatteryState['session']>().toBeNullable();
    expectTypeOf<BatteryState['weekly']>().toBeNullable();
    expectTypeOf<BatteryState['error']>().toBeNullable();
  });

  it('status is a union of known values', () => {
    expectTypeOf<BatteryState['status']>().toEqualTypeOf<
      'ok' | 'loading' | 'login_required' | 'error'
    >();
  });

  it('version is literal 1', () => {
    expectTypeOf<BatteryState['version']>().toEqualTypeOf<1>();
  });
});
