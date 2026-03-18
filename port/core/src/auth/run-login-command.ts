import { persistLoginResult } from './login-persistence.js';
import { startOAuthLogin, TokenResult } from './oauth-login.js';
import { writeStateFile } from '../storage/state-store.js';
import type { BatteryState } from '../contracts/index.js';
import type { PollDeps } from '../runtime/poll-once.js';

interface RunLoginCommandDeps {
  homeDir: string;
  fetchImpl: typeof fetch;
  openBrowser?: (url: string) => Promise<void>;
  startOAuthLoginImpl?: (opts: {
    fetchImpl: typeof fetch;
    openBrowserImpl?: (url: string) => Promise<void>;
  }) => Promise<TokenResult>;
  pollOnceImpl?: (deps: PollDeps) => Promise<BatteryState>;
}

export async function runLoginCommand(deps: RunLoginCommandDeps): Promise<void> {
  const {
    homeDir,
    fetchImpl,
    openBrowser,
    startOAuthLoginImpl = startOAuthLogin,
  } = deps;

  // Import pollOnce lazily so it can be overridden in tests
  let pollOnce: (d: PollDeps) => Promise<BatteryState>;
  if (deps.pollOnceImpl) {
    pollOnce = deps.pollOnceImpl;
  } else {
    const mod = await import('../runtime/poll-once.js');
    pollOnce = mod.pollOnce;
  }

  // 1. Start OAuth login
  const tokens = await startOAuthLoginImpl({
    fetchImpl,
    ...(openBrowser ? { openBrowserImpl: openBrowser } : {}),
  });

  // 2. Persist account and tokens
  await persistLoginResult(homeDir, tokens);

  // 3. Poll once with fresh credentials and write state immediately
  const state = await pollOnce({ fetchImpl, now: Date.now(), homeDir });
  await writeStateFile(homeDir, state);

  console.log('Battery core: login complete');
}
