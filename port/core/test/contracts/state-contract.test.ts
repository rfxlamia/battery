import { describe, expect, it } from 'vitest';
import { batteryStateSchema } from '../../src/contracts/index.js';

describe('batteryStateSchema', () => {
  it('accepts the minimal disconnected state', () => {
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'login_required',
      updatedAt: '2026-03-17T00:00:00.000Z',
    });

    expect(result.success).toBe(true);
  });
});
