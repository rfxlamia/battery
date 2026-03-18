#!/usr/bin/env node
import { getHomeDir } from './config/env.js';
import { pollOnce } from './runtime/poll-once.js';

async function main(): Promise<void> {
  const homeDir = getHomeDir();
  const state = await pollOnce({ fetchImpl: fetch, now: Date.now(), homeDir });
  console.log(`Battery core: status=${state.status}`);
}

main().catch((err: unknown) => {
  console.error('Battery core fatal error:', err);
  process.exit(1);
});
