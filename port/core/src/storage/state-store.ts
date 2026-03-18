import { writeFile, rename, mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { randomBytes } from 'node:crypto';
import type { BatteryState } from '../contracts/index.js';

export async function writeStateFile(homeDir: string, state: BatteryState): Promise<void> {
  const batteryDir = join(homeDir, '.battery');
  await mkdir(batteryDir, { recursive: true });

  const statePath = join(batteryDir, 'state.json');
  const tempPath = join(batteryDir, `.state.${randomBytes(4).toString('hex')}.tmp`);

  await writeFile(tempPath, JSON.stringify(state, null, 2), { mode: 0o600 });
  await rename(tempPath, statePath);
}
