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

## Sign in

After installing, sign in to Claude:

```bash
~/.local/share/battery/core/battery-core.sh login
```

This opens a browser for OAuth. After completing, the following files are written:

- `~/.battery/accounts.json`
- `~/.battery/selected-account-id`
- `~/.battery/tokens/*.json`
- `~/.battery/state.json`

## Verify

```bash
systemctl --user status battery-core.service
cat ~/.battery/state.json
```
