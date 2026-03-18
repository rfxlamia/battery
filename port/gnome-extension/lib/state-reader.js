/**
 * State reader — parses Battery state JSON.
 *
 * parseStateJson() is a pure function that works in both Node.js (tests)
 * and GJS (extension).
 *
 * File I/O lives in extension.js where Gio is properly imported via gi://Gio.
 */

const VALID_STATUSES = new Set(['ok', 'loading', 'login_required', 'error']);

/**
 * Parse and validate a raw JSON string from the Battery state file.
 * Returns the parsed state object, or null if the input is missing or invalid.
 *
 * @param {string|null|undefined} rawJson
 * @returns {object|null}
 */
export function parseStateJson(rawJson) {
  if (rawJson == null) return null;

  let parsed;
  try {
    parsed = JSON.parse(rawJson);
  } catch {
    return null;
  }

  if (!isValidState(parsed)) return null;
  return parsed;
}

/**
 * Lightweight contract validation — must match batteryStateSchema fields.
 * @param {unknown} data
 * @returns {boolean}
 */
function isValidState(data) {
  if (typeof data !== 'object' || data === null) return false;
  if (data.version !== 1) return false;
  if (!VALID_STATUSES.has(data.status)) return false;
  if (!data.freshness || typeof data.freshness.staleAfterSeconds !== 'number') return false;
  if (data.status === 'error' && data.error == null) return false;
  return true;
}
