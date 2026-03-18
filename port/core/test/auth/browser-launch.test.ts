import { describe, expect, it } from 'vitest';
import { getBrowserLaunchCommand } from '../../src/auth/browser-launch.js';

describe('getBrowserLaunchCommand', () => {
  it('uses xdg-open on Linux', () => {
    expect(getBrowserLaunchCommand('https://example.com')).toEqual({
      cmd: 'xdg-open',
      args: ['https://example.com'],
    });
  });
});
