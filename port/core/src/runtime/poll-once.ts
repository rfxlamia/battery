import { batteryStateSchema, type BatteryState } from '../contracts/index.js';
import { readSelectedAccount } from '../storage/account-store.js';
import { readTokens, writeTokens } from '../storage/token-store.js';
import { writeStateFile } from '../storage/state-store.js';
import { refreshIfNeeded } from '../auth/token-refresh.js';
import { fetchUsage } from '../api/anthropic-api.js';
import { readRecentEvents } from '../hooks/read-events.js';
import { reduceSessionState } from '../hooks/session-reducer.js';
import { buildOkState, buildLoginRequiredState, buildErrorState } from './build-state.js';
import type { TokenError } from '../api/api-errors.js';
import type { ApiError } from '../api/api-errors.js';

interface PollDeps {
  fetchImpl: typeof fetch;
  now: number;
  homeDir: string;
}

export async function pollOnce(deps: PollDeps): Promise<BatteryState> {
  const { fetchImpl, now, homeDir } = deps;

  // 1. Load selected account
  const account = await readSelectedAccount(homeDir);
  if (!account) {
    const state = buildLoginRequiredState(now);
    await writeStateFile(homeDir, state);
    return state;
  }

  // 2. Load tokens
  const tokens = await readTokens(homeDir, account.id);
  if (!tokens) {
    const state = buildLoginRequiredState(now);
    await writeStateFile(homeDir, state);
    return state;
  }

  // 3. Refresh tokens if needed, persist replacements
  let refreshedTokens;
  try {
    refreshedTokens = await refreshIfNeeded(tokens, fetchImpl);
  } catch (err) {
    const tokenErr = err as TokenError;
    if (tokenErr.kind === 'no_refresh_token' || tokenErr.kind === 'refresh_failed') {
      const state = buildLoginRequiredState(now);
      await writeStateFile(homeDir, state);
      return state;
    }
    const state = buildErrorState('network_error', tokenErr.message, now);
    await writeStateFile(homeDir, state);
    return state;
  }

  if (refreshedTokens.accessToken !== tokens.accessToken) {
    await writeTokens(homeDir, account.id, refreshedTokens);
  }

  // 4. Fetch usage; handle 401 with force-refresh retry
  let usage;
  try {
    usage = await fetchUsage(fetchImpl, refreshedTokens.accessToken);
  } catch (err) {
    const apiErr = err as ApiError;
    if (apiErr.kind === 'unauthorized') {
      // Force-refresh and retry once
      let retried;
      try {
        const forceRefreshed = await refreshIfNeeded(refreshedTokens, fetchImpl, { force: true });
        await writeTokens(homeDir, account.id, forceRefreshed);
        retried = await fetchUsage(fetchImpl, forceRefreshed.accessToken);
      } catch (retryErr) {
        const retryApiErr = retryErr as ApiError | TokenError;
        if (
          (retryApiErr as TokenError).kind === 'no_refresh_token' ||
          (retryApiErr as TokenError).kind === 'refresh_failed' ||
          (retryApiErr as ApiError).kind === 'unauthorized'
        ) {
          const state = buildLoginRequiredState(now);
          await writeStateFile(homeDir, state);
          return state;
        }
        const state = buildErrorState(
          (retryApiErr as ApiError).kind ?? 'network_error',
          (retryApiErr as ApiError).message ?? String(retryApiErr),
          now,
        );
        await writeStateFile(homeDir, state);
        return state;
      }
      usage = retried;
    } else {
      const state = buildErrorState(
        apiErr.kind,
        apiErr.message,
        now,
        apiErr.retryAfterSeconds,
      );
      await writeStateFile(homeDir, state);
      return state;
    }
  }

  // 5. Read recent hook events and reduce session state
  const events = await readRecentEvents(homeDir, now);
  const session = reduceSessionState(events, now);

  // 6. Build and validate normalized state against the shared contract
  const state = batteryStateSchema.parse(buildOkState(account, usage, session, now));

  // 7. Write state.json
  await writeStateFile(homeDir, state);

  return state;
}
