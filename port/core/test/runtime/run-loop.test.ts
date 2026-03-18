import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { getEffectiveInterval, getServiceCommand, runLoopTick } from '../../src/runtime/run-loop.js';

const sample200 = {
  five_hour: { utilization: 10.0, resets_at: '2026-03-17T13:00:00Z' },
  seven_day: { utilization: 20.0, resets_at: '2026-03-23T00:00:00Z' },
};

describe('getServiceCommand', () => {
  it('contains node', () => {
    expect(getServiceCommand()).toContain('node');
  });
});

describe('getEffectiveInterval', () => {
  it('returns the current interval when not rate limited', () => {
    expect(getEffectiveInterval(300_000, 0)).toBe(300_000);
  });

  it('applies exponential backoff from 60s to 600s', () => {
    expect(getEffectiveInterval(300_000, 1)).toBe(60_000);
    expect(getEffectiveInterval(300_000, 2)).toBe(120_000);
    expect(getEffectiveInterval(300_000, 3)).toBe(240_000);
    expect(getEffectiveInterval(300_000, 4)).toBe(480_000);
    expect(getEffectiveInterval(300_000, 5)).toBe(600_000);
    expect(getEffectiveInterval(300_000, 6)).toBe(600_000);
  });

  it('honors retry-after when it exceeds the computed backoff', () => {
    expect(getEffectiveInterval(300_000, 1, 180)).toBe(180_000);
  });
});

describe('runLoopTick', () => {
  let homeDir: string;
  const now = new Date('2026-03-17T09:00:00Z').getTime();

  beforeEach(async () => {
    homeDir = await mkdtemp(join(tmpdir(), 'battery-loop-test-'));
    await mkdir(join(homeDir, '.battery', 'tokens'), { recursive: true });
    await writeFile(
      join(homeDir, '.battery', 'accounts.json'),
      JSON.stringify([{ id: 'acct-1', name: 'Alice', planTier: 'pro', selected: true }]),
    );
    await writeFile(
      join(homeDir, '.battery', 'tokens', 'acct-1.json'),
      JSON.stringify({
        accessToken: 'valid-token',
        refreshToken: 'rt-valid',
        expiresAt: new Date(now + 2 * 3600 * 1000).toISOString(),
      }),
      { mode: 0o600 },
    );
  });

  it('writes state and returns wroteState=true on success', async () => {
    const mockFetch = async () => new Response(JSON.stringify(sample200), { status: 200 });
    const result = await runLoopTick({
      fetchImpl: mockFetch as typeof fetch,
      now,
      homeDir,
    });
    expect(result).toMatchObject({ wroteState: true });
  });

  it('returns wroteState=true even on login_required (state still written)', async () => {
    const emptyDir = await mkdtemp(join(tmpdir(), 'battery-empty-'));
    await mkdir(join(emptyDir, '.battery'), { recursive: true });
    await writeFile(join(emptyDir, '.battery', 'accounts.json'), JSON.stringify([]));
    const mockFetch = async () => new Response(JSON.stringify(sample200), { status: 200 });
    const result = await runLoopTick({
      fetchImpl: mockFetch as typeof fetch,
      now,
      homeDir: emptyDir,
    });
    expect(result).toMatchObject({ wroteState: true, status: 'login_required' });
  });
});
