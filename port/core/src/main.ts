#!/usr/bin/env node
import { getHomeDir } from './config/env.js';
import { getBatteryPaths } from './config/paths.js';

async function main(): Promise<void> {
  const homeDir = getHomeDir();
  const paths = getBatteryPaths(homeDir);
  console.log(`Battery core starting (state: ${paths.stateFile})`);
}

main().catch((err: unknown) => {
  console.error('Battery core fatal error:', err);
  process.exit(1);
});
