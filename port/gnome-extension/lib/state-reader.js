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
  if (data.version !== 1 || typeof data.updatedAt !== 'string') return false;
  if (!VALID_STATUSES.has(data.status)) return false;
  if (!isFreshness(data.freshness)) return false;
  if (data.account !== undefined && !isAccount(data.account)) return false;
  if (data.session !== undefined && !isSession(data.session)) return false;
  if (data.weekly !== undefined && !isUsageWindow(data.weekly)) return false;
  if (data.status === 'error' && !isErrorState(data.error)) return false;
  return true;
}

function isFreshness(data) {
  return (
    typeof data === 'object' &&
    data !== null &&
    typeof data.staleAfterSeconds === 'number' &&
    Number.isFinite(data.staleAfterSeconds) &&
    data.staleAfterSeconds > 0
  );
}

function isAccount(data) {
  return (
    typeof data === 'object' &&
    data !== null &&
    typeof data.id === 'string' &&
    typeof data.name === 'string' &&
    typeof data.planTier === 'string' &&
    data.isSelected === true
  );
}

function isUsageWindow(data) {
  return (
    typeof data === 'object' &&
    data !== null &&
    typeof data.utilization === 'number' &&
    Number.isFinite(data.utilization) &&
    typeof data.resetsAt === 'string'
  ) || (
    typeof data === 'object' &&
    data !== null &&
    typeof data.utilization === 'number' &&
    Number.isFinite(data.utilization) &&
    data.resetsAt === null
  );
}

function isSession(data) {
  return isUsageWindow(data) &&
    typeof data.isActive === 'boolean';
}

function isErrorState(data) {
  return (
    typeof data === 'object' &&
    data !== null &&
    typeof data.kind === 'string' &&
    typeof data.message === 'string'
  );
}
