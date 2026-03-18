import { describe, expect, it } from 'vitest';
import { getLocalStateStatusForReadError } from '../lib/read-error-status.js';

describe('getLocalStateStatusForReadError', () => {
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

    expect(getLocalStateStatusForReadError(error, mockGio)).toBe('missing');
  });

  it('classifies non-matching Gio errors as invalid', () => {
    const mockGio = {
      io_error_quark: () => 'gio-quark',
      IOErrorEnum: { NOT_FOUND: 1 },
    };
    const error = {
      matches() {
        return false;
      },
    };

    expect(getLocalStateStatusForReadError(error, mockGio)).toBe('invalid');
  });
});
