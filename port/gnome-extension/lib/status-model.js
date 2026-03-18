/**
 * Pure status model helpers — no GNOME Shell dependencies.
 * Maps Battery state contract fields to display strings.
 */

/**
 * Returns the top-bar indicator label for a given Battery state.
 *
 * @param {object} state - Battery state contract object
 * @param {Date} [now] - Current time (defaults to new Date())
 * @returns {string}
 */
export function getIndicatorLabel(state, now = new Date()) {
  if (!state || typeof state !== 'object') return 'Battery';

  const { status, session, freshness, updatedAt } = state;

  if (status === 'login_required') return 'Battery Sign in';
  if (status === 'loading') return 'Battery …';
  if (status === 'error') return 'Battery Error';

  if (status === 'ok') {
    if (isStale(updatedAt, freshness, now)) return 'Battery Stale';
    if (!session) return 'Battery';

    const pct = Math.round(session.utilization * 100);
    const resetText = formatResetTime(session.resetsAt, now);
    return resetText ? `${pct}% · ${resetText}` : `${pct}%`;
  }

  return 'Battery';
}

/**
 * Returns true if updatedAt is older than freshness.staleAfterSeconds.
 *
 * @param {string|null|undefined} updatedAt
 * @param {{staleAfterSeconds: number}|undefined} freshness
 * @param {Date} now
 * @returns {boolean}
 */
export function isStale(updatedAt, freshness, now) {
  if (!updatedAt || !freshness) return false;
  const updated = new Date(updatedAt);
  if (isNaN(updated.getTime())) return false;
  return (now.getTime() - updated.getTime()) / 1000 > freshness.staleAfterSeconds;
}

/**
 * Returns a human-readable reset countdown (e.g. "1h 18m") or null.
 *
 * @param {string|null|undefined} resetsAt
 * @param {Date} now
 * @returns {string|null}
 */
export function formatResetTime(resetsAt, now) {
  if (!resetsAt) return null;
  const reset = new Date(resetsAt);
  if (isNaN(reset.getTime())) return null;
  const diffMs = reset.getTime() - now.getTime();
  if (diffMs <= 0) return null;
  const totalMinutes = Math.floor(diffMs / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

/**
 * Maps a Battery state to a normalized display state kind.
 *
 * @param {object} state
 * @param {Date} [now]
 * @returns {{ kind: 'login_required'|'loading'|'error'|'stale'|'ok'|'unknown' }}
 */
export function getDisplayState(state, now = new Date()) {
  if (!state || typeof state !== 'object') return { kind: 'unknown' };
  const { status, freshness, updatedAt } = state;
  if (status === 'login_required') return { kind: 'login_required' };
  if (status === 'loading') return { kind: 'loading' };
  if (status === 'error') return { kind: 'error' };
  if (status === 'ok') {
    if (isStale(updatedAt, freshness, now)) return { kind: 'stale' };
    return { kind: 'ok' };
  }
  return { kind: 'unknown' };
}
