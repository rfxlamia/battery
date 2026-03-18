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
  const diffMs = reset.getTime() - now.getTime();
  if (diffMs <= 0) return null;
  return formatDuration(Math.floor(diffMs / 60000));
}

/**
 * Formats a duration in minutes as a human-readable string.
 *
 * @param {number} totalMinutes
 * @returns {string}
 */
export function formatDuration(totalMinutes) {
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
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
  if (diffSeconds < 10) return 'just now';
  if (diffSeconds < 60) return `${diffSeconds}s ago`;
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  const diffHours = Math.floor(diffMinutes / 60);
  return `${diffHours}h ago`;
}
