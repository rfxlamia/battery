# Battery Core

Linux background service for Battery.

## Install locally

```bash
cd port/core
npm ci
./install-local.sh
```

The installer will:

- build `dist/`
- install the runtime under `~/.local/share/battery/core/`
- copy `battery-core.service` to `~/.config/systemd/user/`
- reload the user daemon
- enable and start `battery-core.service`

## Verify

```bash
systemctl --user status battery-core.service
```
