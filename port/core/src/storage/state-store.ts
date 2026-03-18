import { writeFile, rename, mkdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { randomBytes } from 'node:crypto';
import { batteryStateSchema, type BatteryState } from '../contracts/index.js';

export async function writeStateFile(homeDir: string, state: BatteryState): Promise<void> {
  const batteryDir = join(homeDir, '.battery');
  await mkdir(batteryDir, { recursive: true, mode: 0o700 });

  const statePath = join(batteryDir, 'state.json');
  const tempPath = join(batteryDir, `.state.${randomBytes(4).toString('hex')}.tmp`);

  await writeFile(tempPath, JSON.stringify(state, null, 2), { mode: 0o600 });
  await rename(tempPath, statePath);
}

export async function readStateFile(homeDir: string): Promise<BatteryState | null> {
  const statePath = join(homeDir, '.battery', 'state.json');
  let raw: string;
  try {
    raw = await readFile(statePath, 'utf8');
  } catch {
    return null;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }

  const result = batteryStateSchema.safeParse(parsed);
  return result.success ? result.data : null;
}
