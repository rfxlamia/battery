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

## Core service dependency

The extension expects `battery-core.service` to be active and writing `~/.battery/state.json`.

- If the core service is not running, the extension will show `Battery Stale`.
- Install verification will fail loudly if the extension is present but the core service is missing.

## Stale state

`Battery Stale` means the core service has not updated `~/.battery/state.json` within the expected freshness window. Check that the core service is active:

```bash
systemctl --user status battery-core.service
```

If the service is inactive, start it:

```bash
systemctl --user start battery-core.service
```

## Verify install

```bash
./scripts/check-install.sh
```

The script checks:
1. `extension.js` is present in the extensions directory
2. The extension is known to GNOME Shell
3. `battery-core.service` is active

It exits non-zero with a clear message if any check fails.

## Development

Run pure-module unit tests (no GNOME Shell required):

```bash
npm test
```

Tests cover `lib/status-model.js`, `lib/time-format.js`, `lib/state-reader.js`, and `lib/popup-view.js`.

### Mock state file

`dev/mock-state.json` has a fixed `updatedAt` timestamp. If it is older than `freshness.staleAfterSeconds` (360s) relative to the current time, the extension will show `Battery Stale` rather than the intended `42% · 1h 18m`. Update the timestamp to the current time when testing the mock state path live in GNOME.
