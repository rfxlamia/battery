import { describe, expect, it } from 'vitest';
import { parseBatteryCommand } from '../../src/cli/command-router.js';

describe('parseBatteryCommand', () => {
  it('defaults to a single poll when no args are provided', () => {
    expect(parseBatteryCommand([])).toEqual({ kind: 'poll-once' });
  });

  it('parses the loop command', () => {
    expect(parseBatteryCommand(['--loop'])).toEqual({ kind: 'loop' });
  });

  it('parses the login command', () => {
    expect(parseBatteryCommand(['login'])).toEqual({ kind: 'login' });
  });
});
