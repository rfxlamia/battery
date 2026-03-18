/**
 * Pure status model helpers — no GNOME Shell dependencies.
 * Maps Battery state contract fields to display strings.
 */
import { formatResetTime } from './time-format.js';

/**
 * Returns the top-bar indicator label for a given Battery state.
 *
 * @param {object} state - Battery state contract object
 * @param {Date} [now] - Current time (defaults to new Date())
 * @returns {string}
 */
export function getIndicatorLabel(state, now = new Date()) {
  if (state?._localStateStatus === 'missing') return 'Battery Stale';
  if (state?._localStateStatus === 'invalid') return 'Battery Error';
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
 * Maps a Battery state to a normalized display state kind.
 *
 * @param {object} state
 * @param {Date} [now]
 * @returns {{ kind: 'login_required'|'loading'|'error'|'stale'|'ok'|'unknown' }}
 */
export function getDisplayState(state, now = new Date()) {
  if (state?._localStateStatus === 'missing') return { kind: 'stale' };
  if (state?._localStateStatus === 'invalid') return { kind: 'error' };
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
