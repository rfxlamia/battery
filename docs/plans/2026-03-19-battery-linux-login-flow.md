# Battery Linux Login Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a real Linux login flow so the TypeScript core can obtain OAuth tokens itself, persist a usable selected account under `~/.battery/`, and let the GNOME extension trigger sign-in instead of only showing `login_required`.

**Architecture:** Reuse the proven Swift auth behavior as the oracle, but keep the Linux surface thin. The core should own PKCE generation, browser launch, callback listening, token exchange, account/token persistence, and immediate state refresh. The GNOME extension should stay lightweight: it only launches the installed core login command when the state requires sign-in.

**Tech Stack:** TypeScript, Node.js `http`/`crypto`/`child_process`, Zod, Vitest, GJS/Gio subprocess APIs, existing `~/.battery/` shared storage

---

## Before You Start

Read these files before touching code:

- Swift auth flow:
  - `/home/v/project/battery/Sources/Services/OAuthService.swift`
  - `/home/v/project/battery/Sources/Services/TokenRefreshService.swift`
  - `/home/v/project/battery/Sources/Services/AccountManager.swift`
  - `/home/v/project/battery/Sources/ViewModels/UsageViewModel.swift:143-236`
  - `/home/v/project/battery/Sources/Utilities/Constants.swift`
- Port auth/storage/runtime:
  - `/home/v/project/battery/port/core/src/main.ts`
  - `/home/v/project/battery/port/core/src/runtime/poll-once.ts`
  - `/home/v/project/battery/port/core/src/storage/account-store.ts`
  - `/home/v/project/battery/port/core/src/storage/token-store.ts`
  - `/home/v/project/battery/port/core/install-local.sh`
  - `/home/v/project/battery/port/gnome-extension/extension.js`
- Parity notes:
  - `/home/v/project/battery/port/fixtures/swift-domains/errors-and-auth.md`
  - `/home/v/project/battery/port/fixtures/examples/auth/token-refresh-failure.md`

Constraints for this plan:

- Do not invent a second auth store outside `~/.battery/`
- Do not add multi-account UI in GNOME yet
- Do not fetch profile/account data from a new API endpoint unless forced; match Swift and create local account metadata first
- Do not make the extension own OAuth logic
- Keep frequent commits after each task

### Definition Of Done

The feature is done when all of these are true:

- `~/.local/share/battery/core/battery-core.sh login` opens the Claude OAuth URL in a browser
- completing OAuth writes `~/.battery/accounts.json`, `~/.battery/selected-account-id`, and `~/.battery/tokens/<account-id>.json`
- the first login immediately writes an `ok` state to `~/.battery/state.json` without waiting for the background loop
- the GNOME extension shows a real sign-in action on `login_required`
- clicking sign-in from GNOME launches the core login command
- after login completes, the extension can refresh into `ok` and show usage

### Recommended Commit Order

1. `feat: add battery core command parsing`
2. `feat: add oauth pkce helpers and browser opener`
3. `feat: add oauth callback listener and code exchange`
4. `feat: persist logged-in account and refresh state`
5. `feat: add gnome sign-in action`
6. `docs: document linux login flow`

### Task 1: Add a real core command surface and installed launcher

**Files:**
- Create: `port/core/src/cli/command-router.ts`
- Create: `port/core/test/cli/command-router.test.ts`
- Modify: `port/core/src/main.ts`
- Modify: `port/core/install-local.sh`
- Modify: `port/core/systemd/battery-core.service`
- Modify: `port/core/test/install/install-local.test.ts`

**Step 1: Write the failing command parser test**

```ts
import { describe, expect, it } from 'vitest';
import { parseBatteryCommand } from '../../src/cli/command-router.js';

describe('parseBatteryCommand', () => {
  it('defaults to a single poll when no args are provided', () => {
    expect(parseBatteryCommand([])).toEqual({ kind: 'poll-once' });
  });

  it('parses the loop command', () => {
    expect(parseBatteryCommand(['--loop'])).toEqual({ kind: 'loop' });
  });

  it('parses the login command', () => {
    expect(parseBatteryCommand(['login'])).toEqual({ kind: 'login' });
  });
});
```

**Step 2: Run the test to verify it fails**

Run: `cd /home/v/project/battery/port/core && npm test -- test/cli/command-router.test.ts`

Expected: FAIL because `parseBatteryCommand` does not exist yet.

**Step 3: Implement the minimal parser**

```ts
export type BatteryCommand =
  | { kind: 'poll-once' }
  | { kind: 'loop' }
  | { kind: 'login' };

export function parseBatteryCommand(argv: string[]): BatteryCommand {
  if (argv.includes('--loop')) return { kind: 'loop' };
  if (argv[0] === 'login') return { kind: 'login' };
  return { kind: 'poll-once' };
}
```

**Step 4: Wire `main.ts` to the new parser**

Update `/home/v/project/battery/port/core/src/main.ts` so it:

- parses `process.argv.slice(2)`
- keeps current `loop` and `poll-once` behavior unchanged
- routes `login` to a placeholder `runLoginCommand()` function that temporarily throws `"not implemented yet"`

Do not build the real login flow in this task.

**Step 5: Replace the installed launcher with a general-purpose core wrapper**

Change `/home/v/project/battery/port/core/install-local.sh` so it writes:

- `~/.local/share/battery/core/battery-core.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec "$NODE_BIN" "$TARGET_DIR/dist/main.js" "$@"
```

- systemd unit should run:

```ini
ExecStart=%h/.local/share/battery/core/battery-core.sh --loop
```

Do not keep a launcher that hardcodes `--loop`; the extension needs a reusable login entry point.

**Step 6: Update the installer smoke test**

Replace ALL occurrences of `run-battery-core.sh` in `port/core/test/install/install-local.test.ts` with `battery-core.sh`. The existing test has three references that must change:

- the hardcoded launcher path in the smoke test (the `launcherPath` variable)
- the `expect(unit).toContain(...)` assertion for `ExecStart`
- the static unit-path assertion in the "ships a systemd unit" test

After updating those, the test must assert:

- `battery-core.sh` is created (not `run-battery-core.sh`)
- the systemd unit uses `ExecStart=%h/.local/share/battery/core/battery-core.sh --loop`
- the logged `npm` and `systemctl` invocations still match exactly

**Step 7: Run the tests**

Run:

```bash
cd /home/v/project/battery/port/core
npm test -- test/cli/command-router.test.ts test/install/install-local.test.ts
npm run build
```

Expected: PASS

**Step 8: Commit**

```bash
git add port/core/src/cli/command-router.ts port/core/test/cli/command-router.test.ts port/core/src/main.ts port/core/install-local.sh port/core/systemd/battery-core.service port/core/test/install/install-local.test.ts
git commit -m "feat: add battery core command parsing"
```

### Task 2: Implement PKCE helpers, OAuth authorize URL building, and browser launch

**Files:**
- Create: `port/core/src/auth/pkce.ts`
- Create: `port/core/src/auth/oauth-authorize.ts`
- Create: `port/core/src/auth/browser-launch.ts`
- Create: `port/core/test/auth/pkce.test.ts`
- Create: `port/core/test/auth/oauth-authorize.test.ts`
- Create: `port/core/test/auth/browser-launch.test.ts`
- Modify: `port/core/src/config/env.ts`

**Step 1: Write the failing PKCE helper test**

```ts
import { describe, expect, it } from 'vitest';
import { createPkcePair } from '../../src/auth/pkce.js';

describe('createPkcePair', () => {
  it('returns a verifier and challenge in URL-safe format', () => {
    const pair = createPkcePair();
    expect(pair.verifier).toMatch(/^[A-Za-z0-9\-_]+$/);
    expect(pair.challenge).toMatch(/^[A-Za-z0-9\-_]+$/);
    expect(pair.verifier.length).toBeGreaterThanOrEqual(43);
  });
});
```

**Step 2: Write the failing authorize URL test**

```ts
import { describe, expect, it } from 'vitest';
import { buildAuthorizeUrl } from '../../src/auth/oauth-authorize.js';
import { OAUTH_AUTHORIZE_URL, OAUTH_CLIENT_ID, OAUTH_SCOPES } from '../../src/config/env.js';

describe('buildAuthorizeUrl', () => {
  it('matches the Swift authorize query shape', () => {
    const url = new URL(buildAuthorizeUrl({
      redirectUri: 'http://localhost:43123/callback',
      state: 'state-123',
      codeChallenge: 'challenge-123',
    }));

    expect(url.origin + url.pathname).toBe(OAUTH_AUTHORIZE_URL);
    expect(url.searchParams.get('client_id')).toBe(OAUTH_CLIENT_ID);
    expect(url.searchParams.get('redirect_uri')).toBe('http://localhost:43123/callback');
    expect(url.searchParams.get('response_type')).toBe('code');
    expect(url.searchParams.get('scope')).toBe(OAUTH_SCOPES);
    expect(url.searchParams.get('code_challenge_method')).toBe('S256');
  });
});
```

**Step 3: Write the failing browser-launch test**

Make the browser opener testable by injection. The pure helper should build the correct command, not actually launch the browser in unit tests.

```ts
import { describe, expect, it } from 'vitest';
import { getBrowserLaunchCommand } from '../../src/auth/browser-launch.js';

describe('getBrowserLaunchCommand', () => {
  it('uses xdg-open on Linux', () => {
    expect(getBrowserLaunchCommand('https://example.com')).toEqual({
      cmd: 'xdg-open',
      args: ['https://example.com'],
    });
  });
});
```

**Step 4: Implement the helpers**

Match Swift behavior in `/home/v/project/battery/Sources/Services/OAuthService.swift` and `/home/v/project/battery/Sources/Utilities/Constants.swift`:

- PKCE verifier = random bytes, base64url encoded
- challenge = SHA-256(verifier), base64url encoded
- state = independent random verifier string
- authorize URL = `https://claude.ai/oauth/authorize`
- browser opener = `xdg-open`

Add `OAUTH_AUTHORIZE_URL` to `port/core/src/config/env.ts` following the existing constant pattern — `OAUTH_CLIENT_ID`, `OAUTH_SCOPES`, and `OAUTH_TOKEN_URL` already live there. Do not hardcode the URL inside `oauth-authorize.ts`; import it from `env.ts`.

**Step 5: Run the auth helper tests**

Run:

```bash
cd /home/v/project/battery/port/core
npm test -- test/auth/pkce.test.ts test/auth/oauth-authorize.test.ts test/auth/browser-launch.test.ts
```

Expected: PASS

**Step 6: Commit**

```bash
git add port/core/src/auth/pkce.ts port/core/src/auth/oauth-authorize.ts port/core/src/auth/browser-launch.ts port/core/test/auth/pkce.test.ts port/core/test/auth/oauth-authorize.test.ts port/core/test/auth/browser-launch.test.ts port/core/src/config/env.ts
git commit -m "feat: add oauth pkce helpers and browser opener"
```

### Task 3: Implement the local OAuth callback server and code exchange

**Files:**
- Create: `port/core/src/auth/oauth-listener.ts`
- Create: `port/core/src/auth/oauth-login.ts`
- Create: `port/core/test/auth/oauth-listener.test.ts`
- Create: `port/core/test/auth/oauth-login.test.ts`

**Step 1: Write the failing callback listener test**

```ts
import { describe, expect, it } from 'vitest';
import { startOAuthListener } from '../../src/auth/oauth-listener.js';

describe('startOAuthListener', () => {
  it('accepts /callback?code=... and resolves the code once', async () => {
    const listener = await startOAuthListener({ path: '/callback', timeoutMs: 2_000 });
    const res = await fetch(`http://127.0.0.1:${listener.port}/callback?code=abc123`);
    expect(await res.text()).toContain('Battery');
    await expect(listener.codePromise).resolves.toBe('abc123');
    await listener.stop();
  });
});
```

**Step 2: Write the failing token exchange test**

```ts
import { describe, expect, it } from 'vitest';
import { exchangeCodeForTokens } from '../../src/auth/oauth-login.js';
import { OAUTH_CLIENT_ID, OAUTH_TOKEN_URL } from '../../src/config/env.js';

describe('exchangeCodeForTokens', () => {
  it('posts the Swift-parity authorization_code body', async () => {
    const calls: Array<{ url: string; body: unknown }> = [];
    const fetchStub = async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return new Response(JSON.stringify({
        access_token: 'access',
        refresh_token: 'refresh',
        expires_in: 3600,
      }), { status: 200 });
    };

    const tokens = await exchangeCodeForTokens({
      code: 'code-123',
      codeVerifier: 'verifier-123',
      redirectUri: 'http://localhost:43123/callback',
      state: 'state-123',
      fetchImpl: fetchStub as typeof fetch,
    });

    expect(calls[0]?.url).toBe(OAUTH_TOKEN_URL);
    expect(calls[0]?.body).toMatchObject({
      grant_type: 'authorization_code',
      code: 'code-123',
      client_id: OAUTH_CLIENT_ID,
      code_verifier: 'verifier-123',
      redirect_uri: 'http://localhost:43123/callback',
      state: 'state-123',
    });
    expect(tokens.accessToken).toBe('access');
  });
});
```

**Step 3: Implement the listener**

Use Node’s `http` server, not raw sockets. The port may differ from Swift’s Darwin implementation, but behavior should match the parity notes:

- bind to a loopback-only address
- choose an ephemeral port
- accept only the configured callback path
- resolve the first `code` parameter
- return a tiny success HTML page
- auto-time out after 5 minutes
- expose `stop()`

**Step 4: Implement token exchange and orchestrated login**

In `/home/v/project/battery/port/core/src/auth/oauth-login.ts`, create helpers for:

- `exchangeCodeForTokens(...)`
- `startOAuthLogin(...)`

`startOAuthLogin()` should:

1. generate verifier/challenge/state
2. start the listener
3. build `redirectUri`
4. build the authorize URL
5. open the browser
6. await the callback code
7. exchange the code for tokens
8. stop the listener

Return:

```ts
{
  accessToken: string;
  refreshToken?: string;
  expiresIn: number;
}
```

**Step 5: Add failure-path tests**

Cover:

- listener timeout
- token exchange non-200 -> descriptive auth error
- browser launch failure -> login command fails loudly

**Step 6: Run auth login tests**

Run:

```bash
cd /home/v/project/battery/port/core
npm test -- test/auth/oauth-listener.test.ts test/auth/oauth-login.test.ts
```

Expected: PASS

**Step 7: Commit**

```bash
git add port/core/src/auth/oauth-listener.ts port/core/src/auth/oauth-login.ts port/core/test/auth/oauth-listener.test.ts port/core/test/auth/oauth-login.test.ts
git commit -m "feat: add oauth callback listener and code exchange"
```

### Task 4: Persist the logged-in account and immediately emit usable state

**Files:**
- Modify: `port/core/src/storage/account-store.ts`
- Modify: `port/core/src/storage/token-store.ts`
- Create: `port/core/src/auth/login-persistence.ts`
- Create: `port/core/test/auth/login-persistence.test.ts`
- Modify: `port/core/test/storage/account-store.test.ts`

**Step 1: Write the failing account persistence test**

Mirror Swift’s post-login behavior from `/home/v/project/battery/Sources/ViewModels/UsageViewModel.swift:148-166`:

```ts
import { describe, expect, it } from 'vitest';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { persistLoginResult } from '../../src/auth/login-persistence.js';

describe('persistLoginResult', () => {
  it('creates Account 1 and selects it on the first login', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-persist-'));

    const result = await persistLoginResult(homeDir, {
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresIn: 3600,
    });

    const accounts = JSON.parse(await readFile(join(homeDir, '.battery', 'accounts.json'), 'utf8'));
    expect(accounts[0]).toMatchObject({
      name: 'Account 1',
      planTier: 'unknown',
      isDefault: true,
    });
    expect(result.accountId).toBe(accounts[0].id);
  });
});
```

**Step 2: Extend `account-store.ts` with write helpers**

Add readonly-safe write helpers:

- `readAllAccounts(homeDir)`
- `writeAccounts(homeDir, accounts)`
- `writeSelectedAccountId(homeDir, accountId)`

Also **export** `readPersistedSelectedAccountId(homeDir)` — it currently exists in `account-store.ts` but is private. `persistLoginResult` in `login-persistence.ts` needs it to determine whether to replace tokens for the existing selected account or create a new one. Export it so the write path can import it without duplicating the logic.

Write Swift-compatible account records, not a new ad-hoc Linux schema:

```json
{
  "id": "<uuid>",
  "name": "Account 1",
  "email": null,
  "planTier": "unknown",
  "isDefault": true,
  "createdAt": "2026-03-19T00:00:00.000Z"
}
```

Current read-side compatibility stays in place.

**Step 3: Implement `persistLoginResult()`**

Match Swift’s pragmatic login semantics:

- if no account exists, create `Account 1`, `isDefault: true`
- if accounts already exist and a selected account exists, replace tokens for the selected account instead of creating duplicate accounts
- if accounts exist but nothing is selected, create `Account N` and select it
- always write:
  - `accounts.json`
  - `selected-account-id`
  - `tokens/<account-id>.json`

Use `crypto.randomUUID()` for new account IDs.

**Step 4: Add tests for reauth/update behavior**

Cover:

- selected account exists -> tokens replaced, no new account
- no selected account but existing accounts -> `Account N+1` created and selected

**Step 5: Run storage and login persistence tests**

Run:

```bash
cd /home/v/project/battery/port/core
npm test -- test/auth/login-persistence.test.ts test/storage/account-store.test.ts test/storage/token-store.test.ts
```

Expected: PASS

**Step 6: Commit**

```bash
git add port/core/src/storage/account-store.ts port/core/src/auth/login-persistence.ts port/core/test/auth/login-persistence.test.ts port/core/test/storage/account-store.test.ts port/core/src/storage/token-store.ts
git commit -m "feat: persist logged-in account and tokens"
```

### Task 5: Wire `battery-core login` end-to-end and refresh state immediately

**Files:**
- Modify: `port/core/src/main.ts`
- Create: `port/core/src/auth/run-login-command.ts`
- Create: `port/core/test/auth/run-login-command.test.ts`
- Modify: `port/core/src/runtime/poll-once.ts` only if a small helper extraction is needed

**Step 1: Write the failing command integration test**

Make the login command orchestrator injectable so it can be tested without opening a real browser:

```ts
import { describe, expect, it } from 'vitest';
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runLoginCommand } from '../../src/auth/run-login-command.js';

describe('runLoginCommand', () => {
  it('persists login output and writes an ok state immediately', async () => {
    const homeDir = await mkdtemp(join(tmpdir(), 'battery-login-command-'));

    await runLoginCommand({
      homeDir,
      fetchImpl: async () => new Response(JSON.stringify({
        access_token: 'access',
        refresh_token: 'refresh',
        expires_in: 3600,
      }), { status: 200 }) as never,
      openBrowser: async () => undefined,
      startOAuthLoginImpl: async () => ({
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 3600,
      }),
      pollOnceImpl: async () => ({
        version: 1,
        status: 'ok',
        updatedAt: new Date().toISOString(),
        freshness: { staleAfterSeconds: 60 },
        account: { id: 'acct-1', name: 'Account 1', planTier: 'unknown', isSelected: true },
        session: { utilization: 0.1, resetsAt: null, isActive: false },
        weekly: { utilization: 0.2, resetsAt: null },
      }),
    });

    const state = JSON.parse(await readFile(join(homeDir, '.battery', 'state.json'), 'utf8'));
    expect(state.status).toBe('ok');
  });
});
```

**Step 2: Implement `runLoginCommand()`**

Behavior:

1. start OAuth login
2. persist account + tokens
3. call `pollOnce()` once with the fresh credentials
4. write the resulting state immediately
5. print a concise success line like `Battery core: login complete`

If OAuth fails:

- keep the previous state file untouched unless a clearer `login_required` write is appropriate
- print the error to stderr
- exit non-zero from `main.ts`

**Step 3: Wire `main.ts`**

Add:

```ts
if (command.kind === 'login') {
  await runLoginCommand({ homeDir, fetchImpl: fetch });
  return;
}
```

Inside `runLoginCommand`, when calling the real `pollOnce` (not the injected stub), pass `now: Date.now()` — the function signature requires `{fetchImpl, now, homeDir}`. Do not break the current `--loop` service path.

**Step 4: Add a manual command verification note to the test**

Document in the plan comments and command output what the engineer should manually verify after implementation:

```bash
~/.local/share/battery/core/battery-core.sh login
```

Expected:

- browser opens
- after approval, `~/.battery/state.json` becomes `ok`

**Step 5: Run the auth command tests and build**

Run:

```bash
cd /home/v/project/battery/port/core
npm test -- test/auth/run-login-command.test.ts
npm run build
```

Expected: PASS

**Step 6: Commit**

```bash
git add port/core/src/main.ts port/core/src/auth/run-login-command.ts port/core/test/auth/run-login-command.test.ts
git commit -m "feat: add battery core login command"
```

### Task 6: Let the GNOME extension launch login when state is `login_required`

**Files:**
- Create: `port/gnome-extension/lib/core-launcher.js`
- Create: `port/gnome-extension/test/core-launcher.test.js`
- Modify: `port/gnome-extension/extension.js`
- Modify: `port/gnome-extension/lib/popup-view.js`
- Modify: `port/gnome-extension/test/popup-view.test.js`
- Modify: `port/gnome-extension/README.md`

**Step 1: Write the failing launcher helper test**

```ts
import { describe, expect, it } from 'vitest';
import { getBatteryCoreLauncherPath } from '../lib/core-launcher.js';

describe('getBatteryCoreLauncherPath', () => {
  it('points at the installed user-local core launcher', () => {
    expect(getBatteryCoreLauncherPath('/home/alice'))
      .toBe('/home/alice/.local/share/battery/core/battery-core.sh');
  });
});
```

**Step 2: Write the failing popup action test**

`buildPopupRows` already returns rows with `loginRequired: true` for `login_required` state and the existing test covers this. Extend it with one additional assertion to verify the row message is present:

```ts
import { describe, expect, it } from 'vitest';
import { buildPopupRows } from '../lib/popup-view.js';

describe('buildPopupRows', () => {
  it('includes login-needed messaging', () => {
    const rows = buildPopupRows({ status: 'login_required', freshness: { staleAfterSeconds: 300 } });
    expect(rows.some((row) => row.loginRequired === true)).toBe(true);
  });
});
```

Do not add a separate `getPrimaryAction` helper — `buildPopupRows` already carries what's needed to decide which action to show in the extension.

**Step 3: Implement the launcher helper**

`lib/core-launcher.js` should expose:

- `getBatteryCoreLauncherPath(homeDir)`
- `getBatteryCoreLoginCommand(homeDir)`

For GJS runtime use:

```js
const proc = Gio.Subprocess.new(
  [launcherPath, 'login'],
  Gio.SubprocessFlags.NONE,
);
proc.init(null);
```

Keep the core command path in one place, not duplicated inside `extension.js`.

**Step 4: Add the GNOME action**

In `/home/v/project/battery/port/gnome-extension/extension.js`:

- when state is `login_required`, add a real clickable `Sign in` action using `menu.addAction('Sign in', ...)` — the same API already used for `Reload state`. Do **not** use `PopupMenuItem` with `sensitive = false` for this; that path is for read-only informational rows and the click will be swallowed.
- keep `Reload state`
- the `Sign in` callback should launch `getBatteryCoreLoginCommand(homeDir)` via `Gio.Subprocess`, then call `this._refresh()` so the extension can re-read state on the next poll interval

Do not move OAuth logic into the extension.

**Step 5: Update README**

Document:

- first install the core
- then install the extension
- clicking `Sign in` in the popup launches browser-based OAuth
- on Wayland, first discovery of a newly installed extension may still require logout/login

**Step 6: Run extension tests**

Run:

```bash
cd /home/v/project/battery/port/gnome-extension
npm test -- test/core-launcher.test.js test/popup-view.test.js test/status-model.test.js
```

Expected: PASS

**Step 7: Commit**

```bash
git add port/gnome-extension/lib/core-launcher.js port/gnome-extension/test/core-launcher.test.js port/gnome-extension/extension.js port/gnome-extension/lib/popup-view.js port/gnome-extension/test/popup-view.test.js port/gnome-extension/README.md
git commit -m "feat: add gnome sign-in action"
```

### Task 7: Final verification, docs, and regression sweep

**Files:**
- Modify: `port/core/README.md`
- Modify: `port/gnome-extension/README.md`
- Modify: `docs/plans/2026-03-19-battery-linux-login-flow.md` only if execution notes need correction after implementation

**Step 1: Update the core README**

Add explicit login instructions:

```bash
~/.local/share/battery/core/battery-core.sh login
```

Document expected artifacts after success:

- `~/.battery/accounts.json`
- `~/.battery/selected-account-id`
- `~/.battery/tokens/*.json`
- `~/.battery/state.json`

**Step 2: Run the full automated verification**

Run:

```bash
cd /home/v/project/battery/port/core
npm test
npm run build

cd /home/v/project/battery/port/gnome-extension
npm test
```

Expected: PASS

**Step 3: Run manual Linux verification**

Run:

```bash
cd /home/v/project/battery/port/core
./install-local.sh
~/.local/share/battery/core/battery-core.sh login

systemctl --user status battery-core.service
cat ~/.battery/state.json
cat ~/.battery/accounts.json
ls ~/.battery/tokens

cd /home/v/project/battery/port/gnome-extension
./install-local.sh
gnome-extensions enable battery@allthingsclaude.local
gnome-extensions info battery@allthingsclaude.local
```

Expected:

- browser opens
- login completes successfully
- state file reaches `ok`
- extension becomes `ACTIVE`
- top bar no longer says `Battery Sign in`

**Step 4: Commit docs and verification tweaks**

```bash
git add port/core/README.md port/gnome-extension/README.md
git commit -m "docs: document linux login flow"
```

### Notes For The Implementer

- The current product failure is not “UI forgot to show login”; it is “Linux login command does not exist.” Keep that truth visible while implementing.
- Reuse Swift’s account creation behavior first:
  - `Account 1`, `Account 2`, ...
  - `planTier: unknown`
  - selected account persisted separately
- Do not block this MVP on fetching profile name/email.
- Do not build multi-account tabs or settings in GNOME now.
- The shortest path to usefulness is:
  - CLI login in core
  - persisted files
  - extension button that launches the CLI login

