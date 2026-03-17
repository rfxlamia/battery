# Battery GNOME Extension MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a lightweight GNOME Shell extension that reads Battery state from the local TypeScript core and shows it in the GNOME top bar.

**Architecture:** Keep the extension thin. It should read local state, render a top-bar indicator, display a popup summary, and expose just enough controls for refresh and login-needed states. Heavy logic stays in the TypeScript core.

**Tech Stack:** GJS, GNOME Shell Extension APIs, local JSON state file, shell install script, Vitest for pure extension modules

---

### Task 1: Scaffold the extension and local install flow

**Files:**
- Create: `port/gnome-extension/package.json`
- Create: `port/gnome-extension/metadata.json`
- Create: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/stylesheet.css`
- Create: `port/gnome-extension/install-local.sh`
- Create: `port/gnome-extension/README.md`
- Create: `port/gnome-extension/lib/status-model.js`
- Create: `port/gnome-extension/test/status-model.test.js`

**Step 1: Write the extension package manifest and first failing test**

Add a tiny local test harness for pure modules:

```json
{
  "name": "@battery/gnome-extension",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "vitest run"
  },
  "devDependencies": {
    "vitest": "^3.2.0"
  }
}
```

Write the first failing status-model test:

```ts
import { describe, expect, it } from 'vitest';
import { getIndicatorLabel } from '../lib/status-model.js';

describe('getIndicatorLabel', () => {
  it('renders login-required state', () => {
    expect(getIndicatorLabel({ status: 'login_required' })).toBe('Battery Sign in');
  });
});
```

Run:

```bash
cd port/gnome-extension
npm install
npm test -- status-model.test.js
```

Expected: FAIL because `getIndicatorLabel` does not exist yet.

**Step 2: Write the extension metadata**

```json
{
  "uuid": "battery@allthingsclaude.local",
  "name": "Battery",
  "description": "Claude usage indicator for GNOME Shell",
  "shell-version": ["46", "47", "48"]
}
```

**Step 3: Write the install script**

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET="$HOME/.local/share/gnome-shell/extensions/battery@allthingsclaude.local"
mkdir -p "$TARGET"
cp metadata.json extension.js stylesheet.css "$TARGET"/
gnome-extensions enable battery@allthingsclaude.local || true
```

Also document that this script installs only the extension layer and expects the Battery core service to be installed separately.

**Step 4: Implement the minimal status model and README**

Implement `getIndicatorLabel()` in `lib/status-model.js` and document:

- how to copy the extension locally
- how to enable it
- how to restart GNOME Shell or log out/in if needed
- that the extension reads the shared Battery state contract rather than owning polling or auth
- that the core user service must be running for real data to appear

Run:

```bash
cd port/gnome-extension
npm test -- status-model.test.js
```

Expected: PASS

**Step 5: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: scaffold battery gnome extension"
```

### Task 2: Render a basic top-bar indicator from a mock state

**Files:**
- Modify: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/dev/mock-state.json`
- Modify: `port/gnome-extension/lib/status-model.js`
- Create: `port/gnome-extension/lib/time-format.js`
- Create: `port/gnome-extension/test/time-format.test.js`

**Step 1: Write failing formatter tests for mock rendering**

```ts
import { describe, expect, it } from 'vitest';
import { getIndicatorLabel } from '../lib/status-model.js';

describe('getIndicatorLabel', () => {
  it('renders ok state from contract-shaped mock data', () => {
    expect(getIndicatorLabel({
      status: 'ok',
      session: { utilization: 0.42, resetsAt: '2026-03-17T01:18:00.000Z', isActive: true },
      freshness: { staleAfterSeconds: 360 },
      updatedAt: '2026-03-17T00:00:00.000Z',
    }, new Date('2026-03-17T00:00:00.000Z'))).toContain('42%');
  });
});
```

**Step 2: Build the first visible panel button**

Create a `PanelMenu.Button` with a label:

```js
this._label = new St.Label({ text: 'Battery --' });
this.add_child(this._label);
```

**Step 3: Add a mock-state loader**

Read `dev/mock-state.json` and set the label from:

- session utilization
- remaining/reset text

Make the mock file contract-shaped so it matches Plan B fields:

- `status`
- `updatedAt`
- `session`
- `weekly`
- `freshness`

Keep formatting logic inside pure helper modules so GNOME shell code only binds state to UI.

**Step 4: Run extension unit tests**

Run:

```bash
cd port/gnome-extension
npm test -- status-model.test.js time-format.test.js
```

Expected: PASS

**Step 5: Verify manually in GNOME**

Run:

```bash
cd port/gnome-extension
./install-local.sh
```

Expected: a visible Battery item appears in the top bar.

**Step 6: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: show basic battery indicator in top bar"
```

### Task 3: Read the real core state file and support contract and stale states

**Files:**
- Modify: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/lib/state-reader.js`
- Modify: `port/gnome-extension/lib/status-model.js`
- Create: `port/gnome-extension/test/state-reader.test.js`

**Step 1: Write failing reader and state-mapping tests**

Cover:

- valid contract-shaped JSON
- missing file
- malformed JSON
- stale state based on `updatedAt` and `freshness.staleAfterSeconds`

Example:

```ts
expect(getDisplayState(staleState, new Date('2026-03-17T00:20:00.000Z'))).toMatchObject({
  kind: 'stale',
});
```

**Step 2: Read `~/.battery/state.json`**

Use Gio file APIs to load and parse the state file.

Keep parsing and status mapping in `lib/state-reader.js` and `lib/status-model.js` so shell integration remains thin.

**Step 3: Map core status to label states**

Examples:

- `login_required` -> `Battery Sign in`
- `loading` -> `Battery ...`
- `ok` -> `42% · 1h 18m`
- `error` -> `Battery Error`
- stale contract state -> `Battery Stale`

Also reject invalid or partial contract data with a safe fallback presentation instead of throwing inside the shell.

**Step 4: Run extension unit tests**

Run:

```bash
cd port/gnome-extension
npm test -- state-reader.test.js status-model.test.js
```

Expected: PASS

**Step 5: Verify manually**

Run:

```bash
cd port/gnome-extension
./install-local.sh
```

Expected: the top-bar label reflects the real local state file if it exists.

Expected also:

- stale state renders as an explicit stale label
- malformed state does not crash the shell extension

**Step 6: Commit**

```bash
git add port/gnome-extension
git commit -m "feat: connect gnome extension to core state"
```

### Task 4: Build the popup summary

**Files:**
- Modify: `port/gnome-extension/extension.js`
- Create: `port/gnome-extension/lib/popup-view.js`
- Modify: `port/gnome-extension/lib/status-model.js`
- Create: `port/gnome-extension/test/popup-view.test.js`

**Step 1: Write failing popup-view tests**

Assert that popup sections are derived from contract-shaped state and include safe fallbacks for:

- login-required
- error
- stale
- ok

**Step 2: Add popup rows for the key Battery state**

Include:

- account name
- plan tier
- session usage
- weekly usage
- reset time
- session active state
- last updated

Also show stale/error/login-needed messaging inside the popup, not only in the top-bar label.

**Step 3: Add a manual refresh action**

For MVP, manual refresh must stay thin:

- it may re-read `state.json`
- it may trigger the extension's local reload path
- it must not start, stop, or supervise the core runtime
- it must not own auth or polling logic

**Step 4: Run extension unit tests**

Run:

```bash
cd port/gnome-extension
npm test -- popup-view.test.js status-model.test.js
```

Expected: PASS

**Step 5: Verify manually**

Expected: clicking the top-bar indicator opens a usable summary popup.

Expected also:

- stale state is clearly identified
- plan tier appears when present
- login-needed and error states are understandable without opening logs

**Step 6: Commit**

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
systemctl --user --quiet is-active battery-core.service
```

**Step 2: Document the expected user result**

```md
After enabling the extension, Battery should appear in the GNOME top bar.
```

Also document:

- the extension expects the Battery core service to be active
- stale state usually means the core is not updating `state.json`
- install verification should fail loudly when the extension is present but the core service is missing

**Step 3: Run the install check**

Run:

```bash
cd port/gnome-extension
./scripts/check-install.sh
```

Expected: PASS when both the extension and the core service are installed correctly.

**Step 4: Commit**

```bash
git add port/gnome-extension
git commit -m "docs: add gnome extension install verification"
```
