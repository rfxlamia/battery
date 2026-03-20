/**
 * Popup view helpers — pure module, no GNOME Shell dependencies.
 *
 * buildPopupRows() computes the data model for the popup.
 * The GJS-side buildPopupContent() lives in extension.js where GJS APIs are available.
 */
import { isStale } from './status-model.js';
import { formatResetTime, formatUpdatedAt } from './time-format.js';

const PLAN_TIER_DISPLAY = {
  pro: 'Pro',
  max: 'Max',
  max_5x: 'Max 5x',
  unknown: 'Unknown',
};

/** Pattern matching generic auto-generated account names like "Account 1", "Account 42". */
const GENERIC_ACCOUNT_RE = /^Account \d+$/;

/**
 * Maps a 0-1 utilization fraction to a color level string.
 * Thresholds mirror Swift's UsageLevel: low<0.5, moderate<0.75, high<0.9, critical>=0.9.
 *
 * @param {number} utilization - 0.0 to 1.0
 * @returns {'green'|'yellow'|'orange'|'red'}
 */
export function utilizationColorLevel(utilization) {
  if (utilization >= 0.9) return 'red';
  if (utilization >= 0.75) return 'orange';
  if (utilization >= 0.5) return 'yellow';
  return 'green';
}

/**
 * Row types:
 *   { label, value }                          — plain key/value row
 *   { label, value, utilization, colorLevel, isProgressRow: true }
 *                                             — gauge row (progress bar + value)
 *   { message, stale?, error?, loginRequired? } — status message row
 */

/**
 * Build the popup row data model from a Battery state object.
 *
 * @param {object|null} state
 * @param {Date} [now]
 * @returns {Array}
 */
export function buildPopupRows(state, now = new Date()) {
  if (state?._localStateStatus === 'missing') {
    return [{ message: 'Data is stale — core service may not be running', stale: true }];
  }

  if (state?._localStateStatus === 'invalid') {
    return [{ message: 'Error: Battery state file is invalid', error: true }];
  }

  if (!state || typeof state !== 'object') {
    return [{ message: 'Battery: no data available' }];
  }

  const { status } = state;

  if (status === 'login_required') {
    return [{ message: 'Sign in to Claude to see usage', loginRequired: true }];
  }

  if (status === 'loading') {
    return [{ message: 'Loading…' }];
  }

  if (status === 'error') {
    const msg = state.error?.message ?? 'An error occurred';
    return [{ message: `Error: ${msg}`, error: true }];
  }

  if (status === 'ok') {
    const rows = [];

    const staleFlag = isStale(state.updatedAt, state.freshness, now);
    if (staleFlag) {
      rows.push({ message: 'Data is stale — core service may not be running', stale: true });
    }

    // Account and plan — only shown when non-generic / non-unknown
    if (state.account) {
      if (!GENERIC_ACCOUNT_RE.test(state.account.name)) {
        rows.push({ label: 'Account', value: state.account.name });
      }
      if (state.account.planTier !== 'unknown') {
        rows.push({
          label: 'Plan',
          value: PLAN_TIER_DISPLAY[state.account.planTier] ?? state.account.planTier,
        });
      }
    }

    // Session — progress row with utilization for gauge rendering
    if (state.session) {
      const pct = Math.round(state.session.utilization * 100);
      const active = state.session.isActive ? ' (active)' : ' (idle)';
      rows.push({
        label: 'Session',
        value: `${pct}%${active}`,
        utilization: state.session.utilization,
        colorLevel: utilizationColorLevel(state.session.utilization),
        isProgressRow: true,
      });

      const resetText = formatResetTime(state.session.resetsAt, now);
      if (resetText) {
        rows.push({ label: 'Resets in', value: resetText });
      }
    }

    // Weekly — progress row with utilization for gauge rendering
    if (state.weekly) {
      const pct = Math.round(state.weekly.utilization * 100);
      rows.push({
        label: 'Weekly',
        value: `${pct}%`,
        utilization: state.weekly.utilization,
        colorLevel: utilizationColorLevel(state.weekly.utilization),
        isProgressRow: true,
      });

      const weeklyReset = formatResetTime(state.weekly.resetsAt, now);
      if (weeklyReset) {
        rows.push({ label: 'Weekly resets in', value: weeklyReset });
      }
    }

    rows.push({ label: 'Updated', value: formatUpdatedAt(state.updatedAt, now) });
    return rows;
  }

  return [{ message: 'Battery: unknown state' }];
}
