import { describe, expect, it } from 'vitest';
import { getBatteryCoreLauncherPath } from '../lib/core-launcher.js';

describe('getBatteryCoreLauncherPath', () => {
  it('points at the installed user-local core launcher', () => {
    expect(getBatteryCoreLauncherPath('/home/alice'))
      .toBe('/home/alice/.local/share/battery/core/battery-core.sh');
  });
});
