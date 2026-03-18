export function getLocalStateStatusForReadFailure({ ok = true, error = null, gioApi } = {}) {
  if (ok === false) {
    return 'missing';
  }

  if (
    error != null &&
    gioApi != null &&
    typeof gioApi.io_error_quark === 'function' &&
    gioApi.IOErrorEnum?.NOT_FOUND !== undefined &&
    typeof error?.matches === 'function'
  ) {
    try {
      if (error.matches(gioApi.io_error_quark(), gioApi.IOErrorEnum.NOT_FOUND)) {
        return 'missing';
      }
    } catch {
      // Fall through to invalid when Gio-specific matching is unavailable.
    }
  }

  if (error?.code === 'ENOENT' || error?.code === 'NOT_FOUND') {
    return 'missing';
  }

  return 'invalid';
}
