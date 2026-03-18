import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import { mkdtemp, writeFile, mkdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadExpected, SAMPLE_200_RAW } from './compat-test-harness.js';
import { pollOnce } from '../../src/runtime/poll-once.js';
import { batteryStateSchema } from '../../src/contracts/index.js';

const mockFetch200 = async () =>
  new Response(JSON.stringify(SAMPLE_200_RAW), { status: 200 });

describe('contract parity', () => {
  let homeDir: string;
  const now = new Date('2026-03-17T09:00:00Z').getTime();

  beforeEach(async () => {
    homeDir = await mkdtemp(join(tmpdir(), 'battery-compat-'));
    await mkdir(join(homeDir, '.battery', 'tokens'), { recursive: true });

    await writeFile(
      join(homeDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', selected: true },
      ]),
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

  afterEach(async () => {
    await rm(homeDir, { recursive: true, force: true });
  });

  it('ok state matches expected contract shape and validates with batteryStateSchema', async () => {
    const expected = await loadExpected<Record<string, unknown>>('contract/ok-state.expected.json');
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir });

    // Verify key contract fields match expected output
    expect(state.status).toBe(expected.status);
    expect(state.version).toBe(expected.version);
    expect(state.account).toMatchObject(expected.account as object);
    expect(state.freshness).toMatchObject(expected.freshness as object);

    // Must also parse against the schema
    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });

  it('emits login_required when no usable account exists', async () => {
    await writeFile(
      join(homeDir, '.battery', 'accounts.json'),
      JSON.stringify([]),
    );
    const expected = await loadExpected<Record<string, unknown>>('contract/login-required.expected.json');
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir });

    expect(state.status).toBe(expected.status);
    expect(state.freshness).toMatchObject(expected.freshness as object);

    const parsed = batteryStateSchema.safeParse(state);
    expect(parsed.success).toBe(true);
  });

  it('includes updatedAt as ISO 8601 datetime', async () => {
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir });

    expect(state.updatedAt).toBeDefined();
    expect(new Date(state.updatedAt).getTime()).not.toBeNaN();
  });

  it('selected account always has isSelected: true', async () => {
    const state = await pollOnce({ fetchImpl: mockFetch200 as typeof fetch, now, homeDir });

    expect(state.account?.isSelected).toBe(true);
  });
});
