import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, readFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { writeStateFile } from '../../src/storage/state-store.js';
import type { BatteryState } from '../../src/contracts/index.js';

describe('writeStateFile', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'battery-test-'));
    await mkdir(join(tmpDir, '.battery'));
  });

  it('writes state to the correct path and returns undefined', async () => {
    const state: BatteryState = {
      version: 1,
      status: 'ok',
      updatedAt: '2026-03-17T08:00:00Z',
      freshness: { staleAfterSeconds: 60 },
    };
    const result = await writeStateFile(tmpDir, state);
    expect(result).toBeUndefined();

    const statePath = join(tmpDir, '.battery', 'state.json');
    const written = JSON.parse(await readFile(statePath, 'utf8')) as Record<string, unknown>;
    expect(written['status']).toBe('ok');
    expect(written['version']).toBe(1);
  });

  it('creates the .battery directory if it does not exist', async () => {
    const freshDir = await mkdtemp(join(tmpdir(), 'battery-new-'));
    const state: BatteryState = {
      version: 1,
      status: 'loading',
      updatedAt: '2026-03-17T08:00:00Z',
      freshness: { staleAfterSeconds: 30 },
    };
    await writeStateFile(freshDir, state);
    const statePath = join(freshDir, '.battery', 'state.json');
    const written = JSON.parse(await readFile(statePath, 'utf8')) as Record<string, unknown>;
    expect(written['status']).toBe('loading');
  });
});
