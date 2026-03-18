import { describe, expect, it } from 'vitest';
import { getIndicatorLabel } from '../lib/status-model.js';

describe('getIndicatorLabel', () => {
  it('renders login-required state', () => {
    expect(getIndicatorLabel({ status: 'login_required' })).toBe('Battery Sign in');
  });
});
