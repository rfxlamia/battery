import { describe, expect, it } from 'vitest';
import { getLocalStateStatusForReadFailure } from '../lib/read-error-status.js';

describe('getLocalStateStatusForReadFailure', () => {
  it('treats a failed load_contents result as missing state', () => {
    expect(getLocalStateStatusForReadFailure({ ok: false })).toBe('missing');
  });

  it('classifies Gio NOT_FOUND errors as missing', () => {
    const mockGio = {
      io_error_quark: () => 'gio-quark',
      IOErrorEnum: { NOT_FOUND: 1 },
    };
    const error = {
      matches(domain, code) {
        return domain === 'gio-quark' && code === 1;
      },
    };

    expect(getLocalStateStatusForReadFailure({ error, gioApi: mockGio })).toBe('missing');
  });

  it('falls back to generic ENOENT codes when Gio helpers are unavailable', () => {
    expect(getLocalStateStatusForReadFailure({ error: { code: 'ENOENT' } })).toBe('missing');
  });

  it('treats throwing Gio matchers with ENOENT fallback as missing', () => {
    const mockGio = {
      io_error_quark: () => 'gio-quark',
      IOErrorEnum: { NOT_FOUND: 1 },
    };
    const error = {
      code: 'ENOENT',
      matches() {
        throw new Error('broken matcher');
      },
    };

    expect(getLocalStateStatusForReadFailure({ error, gioApi: mockGio })).toBe('missing');
  });

  it('classifies non-matching errors as invalid', () => {
    const mockGio = {
      io_error_quark: () => 'gio-quark',
      IOErrorEnum: { NOT_FOUND: 1 },
    };
    const error = {
      code: 'EPERM',
      matches() {
        return false;
      },
    };

    expect(getLocalStateStatusForReadFailure({ error, gioApi: mockGio })).toBe('invalid');
  });
});
