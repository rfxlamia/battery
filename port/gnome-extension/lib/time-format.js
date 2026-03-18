/**
 * Pure time formatting helpers — no GNOME Shell dependencies.
 */

/**
 * Returns a human-readable countdown to a reset time (e.g. "1h 18m") or null.
 *
 * @param {string|null|undefined} resetsAt - ISO 8601 date string
 * @param {Date} now
 * @returns {string|null}
 */
export function formatResetTime(resetsAt, now) {
  if (!resetsAt) return null;
  const reset = new Date(resetsAt);
  if (isNaN(reset.getTime())) return null;
  const diffSeconds = Math.floor((reset.getTime() - now.getTime()) / 1000);
  if (diffSeconds <= 0) return null;
  return formatDuration(diffSeconds);
}

/**
 * Formats a duration in seconds using the Swift shortDuration rules.
 *
 * @param {number} totalSeconds
 * @returns {string}
 */
export function formatDuration(totalSeconds) {
  if (totalSeconds <= 0) return '0s';

  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m`;
  if (seconds > 0) return `${seconds}s`;
  return '< 1m';
}

/**
 * Returns a short human-readable relative time (e.g. "2m ago", "just now").
 *
 * @param {string|null|undefined} updatedAt - ISO 8601 date string
 * @param {Date} now
 * @returns {string}
 */
export function formatUpdatedAt(updatedAt, now) {
  if (!updatedAt) return 'unknown';
  const updated = new Date(updatedAt);
  if (isNaN(updated.getTime())) return 'unknown';
  const diffSeconds = Math.floor((now.getTime() - updated.getTime()) / 1000);
  if (diffSeconds < 60) return 'just now';
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}
