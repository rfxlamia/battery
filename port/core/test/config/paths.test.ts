import { describe, expect, it } from 'vitest';
import { getBatteryPaths } from '../../src/config/paths.js';

describe('getBatteryPaths', () => {
  it('resolves Linux battery paths under the user home directory', () => {
    expect(getBatteryPaths('/tmp/alice').stateFile).toBe('/tmp/alice/.battery/state.json');
    expect(getBatteryPaths('/tmp/alice').accountsFile).toBe('/tmp/alice/.battery/accounts.json');
  });

  it('includes all expected path keys', () => {
    const paths = getBatteryPaths('/home/user');
    expect(paths.rootDir).toBe('/home/user/.battery');
    expect(paths.eventsFile).toBe('/home/user/.battery/events.jsonl');
    expect(paths.tokensDir).toBe('/home/user/.battery/tokens');
  });
});
