import { describe, expect, it } from 'vitest';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const coreDir = fileURLToPath(new URL('../..', import.meta.url));

describe('local installer paths', () => {
  it('installs the core into the fixed user-local data directory', async () => {
    const script = await readFile(join(coreDir, 'install-local.sh'), 'utf8');
    expect(script).toContain('TARGET_DIR="$HOME/.local/share/battery/core"');
    expect(script).toContain('UNIT_DIR="$HOME/.config/systemd/user"');
    expect(script).not.toContain('XDG_DATA_HOME');
    expect(script).not.toContain('XDG_CONFIG_HOME');
  });

  it('ships a systemd unit that points at the launcher script path', async () => {
    const unit = await readFile(join(coreDir, 'systemd', 'battery-core.service'), 'utf8');
    expect(unit).toContain('ExecStart=%h/.local/share/battery/core/run-battery-core.sh');
  });
});
