/**
 * State reader — parses Battery state JSON.
 *
 * parseStateJson() is a pure function that works in both Node.js (tests)
 * and GJS (extension). readStateFile() uses Gio and is GJS-only.
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

/**
 * Read and parse the Battery state file using Gio (GJS only).
 * Returns null on any error — safe to call from extension.js.
 *
 * @param {string} filePath - Absolute path to state.json
 * @returns {object|null}
 */
export function readStateFile(filePath) {
  // This function uses GJS Gio APIs — not available in Node test environment.
  // In tests, use parseStateJson() directly.
  try {
    // Dynamic import of Gio so this module can still be imported in tests
    // (the import will fail gracefully since Gio is undefined in Node).
    const Gio = globalThis.imports?.gi?.Gio ?? null;
    if (!Gio) {
      // Running in Node (tests) — return null; tests use parseStateJson() directly.
      return null;
    }

    const file = Gio.File.new_for_path(filePath);
    const [ok, contents] = file.load_contents(null);
    if (!ok) return null;

    const rawJson = new TextDecoder().decode(contents);
    return parseStateJson(rawJson);
  } catch {
    return null;
  }
}
