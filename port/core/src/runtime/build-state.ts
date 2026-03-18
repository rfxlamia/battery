import type { BatteryState } from '../contracts/index.js';
import type { SelectedAccount } from '../storage/account-store.js';
import type { UsageResponse } from '../api/anthropic-api.js';
import type { SessionState } from '../hooks/session-reducer.js';

const STALE_AFTER_ACTIVE_SECONDS = 60;
const STALE_AFTER_IDLE_SECONDS = 300;

export function buildOkState(
  account: SelectedAccount,
  usage: UsageResponse,
  session: SessionState,
  nowMs: number,
): BatteryState {
  const fiveHour = usage.fiveHour;
  const sevenDay = usage.sevenDay;

  return {
    version: 1,
    status: 'ok',
    updatedAt: new Date(nowMs).toISOString(),
    account: {
      id: account.id,
      name: account.name,
      planTier: account.planTier,
      isSelected: true,
    },
    session: {
      // API returns 0–100; contract expects 0.0–1.0
      utilization: fiveHour ? fiveHour.utilization / 100 : 0,
      resetsAt: fiveHour?.resetsAt ?? null,
      isActive: session.isActive,
    },
    weekly: {
      utilization: sevenDay.utilization / 100,
      resetsAt: sevenDay.resetsAt ?? null,
    },
    freshness: {
      staleAfterSeconds: session.isActive ? STALE_AFTER_ACTIVE_SECONDS : STALE_AFTER_IDLE_SECONDS,
    },
  };
}

export function buildLoginRequiredState(nowMs: number): BatteryState {
  return {
    version: 1,
    status: 'login_required',
    updatedAt: new Date(nowMs).toISOString(),
    freshness: { staleAfterSeconds: STALE_AFTER_IDLE_SECONDS },
  };
}

export function buildErrorState(
  kind: BatteryState['error'] extends { kind: infer K } | undefined ? K : never,
  message: string,
  nowMs: number,
  retryAfterSeconds?: number,
): BatteryState {
  return {
    version: 1,
    status: 'error',
    updatedAt: new Date(nowMs).toISOString(),
    freshness: { staleAfterSeconds: retryAfterSeconds ?? STALE_AFTER_IDLE_SECONDS },
    error: {
      kind,
      message,
      ...(retryAfterSeconds !== undefined ? { retryAfterSeconds } : {}),
    },
  };
}
