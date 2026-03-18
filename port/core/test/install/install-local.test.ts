import { describe, expect, it } from 'vitest';
import { chmod, mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const coreDir = fileURLToPath(new URL('../..', import.meta.url));
const execFileAsync = promisify(execFile);

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
    expect(unit).toContain('ExecStart=%h/.local/share/battery/core/battery-core.sh --loop');
  });

  it('creates the launcher script and user unit in a temp home during install', async () => {
    const sandboxDir = await mkdtemp(join(tmpdir(), 'battery-install-smoke-'));
    const fakeHome = join(sandboxDir, 'home');
    const fakeCoreDir = join(sandboxDir, 'core');
    const fakeBinDir = join(sandboxDir, 'bin');
    const fakeDistDir = join(fakeCoreDir, 'dist');
    const fakeSystemdDir = join(fakeCoreDir, 'systemd');
    const npmLogPath = join(sandboxDir, 'npm.log');
    const systemctlLogPath = join(sandboxDir, 'systemctl.log');

    await mkdir(fakeHome, { recursive: true });
    await mkdir(fakeBinDir, { recursive: true });
    await mkdir(fakeDistDir, { recursive: true });
    await mkdir(fakeSystemdDir, { recursive: true });

    const installScript = await readFile(join(coreDir, 'install-local.sh'), 'utf8');
    const systemdUnit = await readFile(join(coreDir, 'systemd', 'battery-core.service'), 'utf8');
    await writeFile(join(fakeCoreDir, 'install-local.sh'), installScript, { mode: 0o755 });
    await writeFile(join(fakeCoreDir, 'package.json'), '{}\n');
    await writeFile(join(fakeCoreDir, 'package-lock.json'), '{}\n');
    await writeFile(join(fakeDistDir, 'main.js'), 'console.log("battery");\n');
    await writeFile(join(fakeSystemdDir, 'battery-core.service'), systemdUnit);

    const npmStub = join(fakeBinDir, 'npm');
    const systemctlStub = join(fakeBinDir, 'systemctl');
    await writeFile(
      npmStub,
      '#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "$*" >> "$BATTERY_TEST_NPM_LOG"\nexit 0\n',
      { mode: 0o755 },
    );
    await writeFile(
      systemctlStub,
      '#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "$*" >> "$BATTERY_TEST_SYSTEMCTL_LOG"\nexit 0\n',
      { mode: 0o755 },
    );
    await chmod(npmStub, 0o755);
    await chmod(systemctlStub, 0o755);

    await execFileAsync('/bin/bash', [join(fakeCoreDir, 'install-local.sh')], {
      cwd: fakeCoreDir,
      env: {
        ...process.env,
        BATTERY_TEST_NPM_LOG: npmLogPath,
        BATTERY_TEST_SYSTEMCTL_LOG: systemctlLogPath,
        HOME: fakeHome,
        PATH: `${fakeBinDir}:${process.env['PATH'] ?? ''}`,
      },
    });

    const launcherPath = join(fakeHome, '.local', 'share', 'battery', 'core', 'battery-core.sh');
    const unitPath = join(fakeHome, '.config', 'systemd', 'user', 'battery-core.service');
    const launcher = await readFile(launcherPath, 'utf8');
    const unit = await readFile(unitPath, 'utf8');
    const npmLog = (await readFile(npmLogPath, 'utf8')).trim().split('\n');
    const systemctlLog = (await readFile(systemctlLogPath, 'utf8')).trim().split('\n');

    expect(launcher).toContain('dist/main.js');
    expect(unit).toContain('ExecStart=%h/.local/share/battery/core/battery-core.sh --loop');
    expect(npmLog).toEqual([
      'ci',
      'run build',
      `ci --omit=dev --prefix ${join(fakeHome, '.local', 'share', 'battery', 'core')}`,
    ]);
    expect(systemctlLog).toEqual([
      '--user daemon-reload',
      '--user enable --now battery-core.service',
    ]);
  });
});
