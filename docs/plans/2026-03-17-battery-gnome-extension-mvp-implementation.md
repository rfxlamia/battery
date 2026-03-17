# Battery GNOME Extension MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a lightweight GNOME Shell extension that reads Battery state from the local TypeScript core and shows it in the GNOME top bar.

**Architecture:** Keep the extension thin. It should read local state, render a top-bar indicator, display a popup summary, and expose just enough controls for refresh and login-needed states. Heavy logic stays in the TypeScript core.

**Tech Stack:** GJS, GNOME Shell Extension APIs, local JSON state file, shell install script

---

### Task 1: Scaffold the extension and local install flow

**Files:**
- Create: `port/gnome-extension/metadata.json`
- Create: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/stylesheet.css`
- Create: `port/gnome-extension/install-local.sh`
- Create: `port/gnome-extension/README.md`

**Step 1: Write the extension metadata**

```json
{
  "uuid": "battery@allthingsclaude.local",
  "name": "Battery",
  "description": "Claude usage indicator for GNOME Shell",
  "shell-version": ["46", "47", "48"]
}
```

**Step 2: Write the install script**

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET="$HOME/.local/share/gnome-shell/extensions/battery@allthingsclaude.local"
mkdir -p "$TARGET"
cp metadata.json extension.js stylesheet.css "$TARGET"/
gnome-extensions enable battery@allthingsclaude.local || true
```

**Step 3: Write the first README**

Document:

- how to copy the extension locally
- how to enable it
- how to restart GNOME Shell or log out/in if needed

**Step 4: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: scaffold battery gnome extension"
```

### Task 2: Render a basic top-bar indicator from a mock state

**Files:**
- Modify: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/dev/mock-state.json`

**Step 1: Build the first visible panel button**

Create a `PanelMenu.Button` with a label:

```js
this._label = new St.Label({ text: 'Battery --' });
this.add_child(this._label);
```

**Step 2: Add a mock-state loader**

Read `dev/mock-state.json` and set the label from:

- session utilization
- remaining/reset text

**Step 3: Verify manually in GNOME**

Run:

```bash
cd port/gnome-extension
./install-local.sh
```

Expected: a visible Battery item appears in the top bar.

**Step 4: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: show basic battery indicator in top bar"
```

### Task 3: Read the real core state file and support error states

**Files:**
- Modify: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/lib/state-reader.js`

**Step 1: Read `~/.battery/state.json`**

Use Gio file APIs to load and parse the state file.

**Step 2: Map core status to label states**

Examples:

- `login_required` -> `Battery Sign in`
- `loading` -> `Battery ...`
- `ok` -> `42% · 1h 18m`
- `error` -> `Battery Error`

**Step 3: Verify manually**

Run:

```bash
cd port/gnome-extension
./install-local.sh
```

Expected: the top-bar label reflects the real local state file if it exists.

**Step 4: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: connect gnome extension to core state"
```

### Task 4: Build the popup summary

**Files:**
- Modify: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/lib/popup-view.js`

**Step 1: Add popup rows for the key Battery state**

Include:

- account name
- session usage
- weekly usage
- reset time
- session active state
- last updated

**Step 2: Add a manual refresh action**

For MVP, this can call a local command or just re-read `state.json` if the core is already refreshing independently.

**Step 3: Verify manually**

Expected: clicking the top-bar indicator opens a usable summary popup.

**Step 4: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: add battery popup summary for gnome"
```

### Task 5: Add the first end-to-end install check

**Files:**
- Modify: `port/gnome-extension/README.md`
- Create: `port/gnome-extension/scripts/check-install.sh`

**Step 1: Write a small install validation script**

```bash
#!/usr/bin/env bash
set -euo pipefail

gnome-extensions info battery@allthingsclaude.local
test -f "$HOME/.local/share/gnome-shell/extensions/battery@allthingsclaude.local/extension.js"
```

**Step 2: Document the expected user result**

```md
After enabling the extension, Battery should appear in the GNOME top bar.
```

**Step 3: Commit**

```bash
git add port/gnome-extension
git commit -m "docs: add gnome extension install verification"
```
