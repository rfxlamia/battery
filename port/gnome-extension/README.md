# Battery GNOME Extension

Displays Claude usage from the Battery core service in the GNOME top bar.

## Architecture

This extension is a thin shell integration layer. It:
- Reads `~/.battery/state.json` (written by the Battery core service)
- Renders a top-bar label and popup summary
- Does **not** own polling, authentication, or session tracking

Heavy logic lives in the Battery core TypeScript service. The extension reads shared state; it does not produce it.

## Prerequisites

- GNOME Shell 46, 47, or 48
- Battery core user service installed and running (`battery-core.service`)

## Install

```bash
cd port/gnome-extension
npm install        # install dev dependencies (for tests only)
./install-local.sh
```

The install script copies `extension.js`, `metadata.json`, `stylesheet.css`, and `lib/` to:

```
~/.local/share/gnome-shell/extensions/battery@allthingsclaude.local/
```

## Enable

```bash
gnome-extensions enable battery@allthingsclaude.local
```

## Reload GNOME Shell

- **X11:** Press `Alt+F2`, type `r`, press `Enter`
- **Wayland:** Log out and log back in

## What you should see

After enabling the extension, **Battery** should appear in the GNOME top bar showing your current session utilization (e.g. `42% · 1h 18m`).

| State | Label |
|-------|-------|
| Normal | `42% · 1h 18m` |
| Login needed | `Battery Sign in` |
| Loading | `Battery …` |
| Stale data | `Battery Stale` |
| Error | `Battery Error` |

## Stale state

`Battery Stale` means the core service has not updated `~/.battery/state.json` within the expected window. Check that `battery-core.service` is active:

```bash
systemctl --user status battery-core.service
```

## Verify install

```bash
./scripts/check-install.sh
```

## Development

Run pure-module unit tests (no GNOME Shell required):

```bash
npm test
```

Tests cover `lib/status-model.js`, `lib/time-format.js`, `lib/state-reader.js`, and `lib/popup-view.js`.
