import { batteryStateSchema, type BatteryState } from '../contracts/index.js';
import { readSelectedAccount } from '../storage/account-store.js';
import { readTokens, writeTokens } from '../storage/token-store.js';
import { readStateFile, writeStateFile } from '../storage/state-store.js';
import { refreshIfNeeded } from '../auth/token-refresh.js';
import { fetchUsage } from '../api/anthropic-api.js';
import { readRecentEvents } from '../hooks/read-events.js';
import { reduceSessionState } from '../hooks/session-reducer.js';
import {
  buildOkState,
  buildCachedOkState,
  buildLoginRequiredState,
  buildErrorState,
} from './build-state.js';
import type { TokenError } from '../api/api-errors.js';
import type { ApiError } from '../api/api-errors.js';

export interface PollDeps {
  fetchImpl: typeof fetch;
  now: number;
  homeDir: string;
}

export interface PollOutcome {
  state: BatteryState;
  rateLimited: boolean;
  retryAfterSeconds?: number;
  sessionActive: boolean;
}

export async function pollOnceWithMeta(deps: PollDeps): Promise<PollOutcome> {
  const { fetchImpl, now, homeDir } = deps;
  const recentEvents = await readRecentEvents(homeDir, now);
  const session = reduceSessionState(recentEvents, now);

  // 1. Load selected account
  const account = await readSelectedAccount(homeDir);
  if (!account) {
    const state = buildLoginRequiredState(now);
    await writeStateFile(homeDir, state);
    return { state, rateLimited: false, sessionActive: session.isActive };
  }

  // 2. Load tokens
  const tokens = await readTokens(homeDir, account.id);
  if (!tokens) {
    const state = buildLoginRequiredState(now);
    await writeStateFile(homeDir, state);
    return { state, rateLimited: false, sessionActive: session.isActive };
  }

  // 3. Refresh tokens if needed, persist replacements
  let refreshedTokens;
  try {
    refreshedTokens = await refreshIfNeeded(tokens, fetchImpl);
  } catch (err) {
    const tokenErr = err as TokenError;
    if (tokenErr.kind === 'no_refresh_token') {
      const state = buildLoginRequiredState(now);
      await writeStateFile(homeDir, state);
      return { state, rateLimited: false, sessionActive: session.isActive };
    }
    if (tokenErr.kind === 'refresh_failed') {
      if (tokenErr.statusCode === 429) {
        const state = buildErrorState('server_error', tokenErr.message, now);
        await writeStateFile(homeDir, state);
        return { state, rateLimited: false, sessionActive: session.isActive };
      }
      if (tokenErr.statusCode !== undefined && tokenErr.statusCode >= 500) {
        const state = buildErrorState('server_error', tokenErr.message, now);
        await writeStateFile(homeDir, state);
        return { state, rateLimited: false, sessionActive: session.isActive };
      }
      const state = buildLoginRequiredState(now);
      await writeStateFile(homeDir, state);
      return { state, rateLimited: false, sessionActive: session.isActive };
    }
    const state = buildErrorState('network_error', tokenErr.message, now);
    await writeStateFile(homeDir, state);
    return { state, rateLimited: false, sessionActive: session.isActive };
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
          (retryApiErr as ApiError).kind === 'unauthorized'
        ) {
          const state = buildLoginRequiredState(now);
          await writeStateFile(homeDir, state);
          return { state, rateLimited: false, sessionActive: session.isActive };
        }
        if ((retryApiErr as TokenError).kind === 'refresh_failed') {
          const refreshErr = retryApiErr as TokenError;
          if (refreshErr.statusCode === 429) {
            const state = buildErrorState('server_error', refreshErr.message, now);
            await writeStateFile(homeDir, state);
            return { state, rateLimited: false, sessionActive: session.isActive };
          }
          if (refreshErr.statusCode !== undefined && refreshErr.statusCode >= 500) {
            const state = buildErrorState('server_error', refreshErr.message, now);
            await writeStateFile(homeDir, state);
            return { state, rateLimited: false, sessionActive: session.isActive };
          }
          const state = buildLoginRequiredState(now);
          await writeStateFile(homeDir, state);
          return { state, rateLimited: false, sessionActive: session.isActive };
        }
        const state = buildErrorState(
          (retryApiErr as ApiError).kind ?? 'network_error',
          (retryApiErr as ApiError).message ?? String(retryApiErr),
          now,
        );
        await writeStateFile(homeDir, state);
        return { state, rateLimited: false, sessionActive: session.isActive };
      }
      usage = retried;
    } else {
      if (apiErr.kind === 'rate_limited') {
        const cachedState = await readStateFile(homeDir);
        if (cachedState?.status === 'ok') {
          const refreshedCachedState = buildCachedOkState(
            cachedState,
            session,
            now,
            Math.max(apiErr.retryAfterSeconds ?? 0, 600),
          );
          await writeStateFile(homeDir, refreshedCachedState);
          return {
            state: refreshedCachedState,
            rateLimited: true,
            sessionActive: session.isActive,
            ...(apiErr.retryAfterSeconds !== undefined
              ? { retryAfterSeconds: apiErr.retryAfterSeconds }
              : {}),
          };
        }
      }
      const state = buildErrorState(
        apiErr.kind,
        apiErr.message,
        now,
        apiErr.retryAfterSeconds,
      );
      await writeStateFile(homeDir, state);
      return {
        state,
        rateLimited: apiErr.kind === 'rate_limited',
        sessionActive: session.isActive,
        ...(apiErr.retryAfterSeconds !== undefined
          ? { retryAfterSeconds: apiErr.retryAfterSeconds }
          : {}),
      };
    }
  }

  // 5. Build and validate normalized state against the shared contract
  const state = batteryStateSchema.parse(buildOkState(account, usage, session, now));

  // 6. Write state.json
  await writeStateFile(homeDir, state);

  return { state, rateLimited: false, sessionActive: session.isActive };
}

export async function pollOnce(deps: PollDeps): Promise<BatteryState> {
  const outcome = await pollOnceWithMeta(deps);
  return outcome.state;
}
