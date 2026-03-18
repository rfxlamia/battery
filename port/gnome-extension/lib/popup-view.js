/**
 * Popup view helpers — pure module, no GNOME Shell dependencies.
 *
 * buildPopupRows() computes the data model for the popup.
 * The GJS-side buildPopupContent() lives in extension.js where GJS APIs are available.
 */
import { isStale } from './status-model.js';
import { formatResetTime, formatUpdatedAt } from './time-format.js';

/**
 * Row types:
 *   { label: string, value: string }              — key/value data row
 *   { message: string, stale?: true, error?: true, loginRequired?: true }
 *                                                  — status message row
 */

/**
 * Build the popup row data model from a Battery state object.
 *
 * @param {object|null} state
 * @param {Date} [now]
 * @returns {Array<{label?: string, value?: string, message?: string, stale?: boolean, error?: boolean, loginRequired?: boolean}>}
 */
export function buildPopupRows(state, now = new Date()) {
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

    if (state.account) {
      rows.push({ label: 'Account', value: state.account.name });
      rows.push({ label: 'Plan', value: state.account.planTier });
    }

    if (state.session) {
      const sessionPct = `${Math.round(state.session.utilization * 100)}%`;
      const sessionActive = state.session.isActive ? ' (active)' : ' (idle)';
      rows.push({ label: 'Session', value: sessionPct + sessionActive });

      const resetText = formatResetTime(state.session.resetsAt, now);
      if (resetText) {
        rows.push({ label: 'Resets in', value: resetText });
      }
    }

    if (state.weekly) {
      const weeklyPct = `${Math.round(state.weekly.utilization * 100)}%`;
      rows.push({ label: 'Weekly', value: weeklyPct });

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
