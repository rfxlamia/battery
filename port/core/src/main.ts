#!/usr/bin/env node
import { getHomeDir } from './config/env.js';
import { pollOnce } from './runtime/poll-once.js';
import { runLoop } from './runtime/run-loop.js';

async function main(): Promise<void> {
  const homeDir = getHomeDir();

  if (process.argv.includes('--loop')) {
    // Long-running mode for systemd --user service
    await runLoop(homeDir);
  } else {
    // Single poll — emit state and exit (for scripts and testing)
    const state = await pollOnce({ fetchImpl: fetch, now: Date.now(), homeDir });
    console.log(`Battery core: status=${state.status}`);
  }
}

main().catch((err: unknown) => {
  console.error('Battery core fatal error:', err);
  process.exit(1);
});
