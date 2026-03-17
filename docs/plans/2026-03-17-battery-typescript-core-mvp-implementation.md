# Battery TypeScript Core MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first Linux-focused TypeScript core that reads local state, talks to the Anthropic API, and emits normalized Battery state for other frontends.

**Architecture:** Keep the runtime small and behavior-driven. The core should be a local process with focused modules for config, token storage, polling, hook-event reading, state reduction, and state-file writing.

**Tech Stack:** TypeScript, npm, Node.js, Zod, Vitest

---

### Task 1: Add runtime entry points and config paths

**Files:**
- Modify: `port/core/package.json`
- Create: `port/core/src/main.ts`
- Create: `port/core/src/config/paths.ts`
- Create: `port/core/src/config/env.ts`
- Create: `port/core/test/config/paths.test.ts`

**Step 1: Write the failing paths test**

```ts
import { describe, expect, it } from 'vitest';
import { getBatteryPaths } from '../../src/config/paths.js';

describe('getBatteryPaths', () => {
  it('resolves Linux battery paths under the user home directory', () => {
    expect(getBatteryPaths('/tmp/alice').stateFile).toBe('/tmp/alice/.battery/state.json');
    expect(getBatteryPaths('/tmp/alice').accountsFile).toBe('/tmp/alice/.battery/accounts.json');
  });
});
```

**Step 2: Run test to verify it fails**

Run: `cd port/core && npm test -- paths.test.ts`

Expected: FAIL because `getBatteryPaths` does not exist yet.

**Step 3: Implement the minimal config module**

```ts
export function getBatteryPaths(homeDir: string) {
  return {
    rootDir: `${homeDir}/.battery`,
    stateFile: `${homeDir}/.battery/state.json`,
    eventsFile: `${homeDir}/.battery/events.jsonl`,
    accountsFile: `${homeDir}/.battery/accounts.json`,
    tokensDir: `${homeDir}/.battery/tokens`,
  };
}
```

**Step 4: Run the test**

Run: `cd port/core && npm test -- paths.test.ts`

Expected: PASS

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: add core runtime path resolution"
```

### Task 2: Implement selected-account storage, token storage, and state-file writing

**Files:**
- Create: `port/core/src/storage/account-store.ts`
- Create: `port/core/src/storage/token-store.ts`
- Create: `port/core/src/storage/state-store.ts`
- Create: `port/core/test/storage/account-store.test.ts`
- Create: `port/core/test/storage/token-store.test.ts`
- Create: `port/core/test/storage/state-store.test.ts`

**Step 1: Write failing tests for local storage behavior**

```ts
expect(await readSelectedAccount(tmpDir)).toMatchObject({ id: 'acct-1' });
expect(await writeStateFile(tmpDir, state)).toBeUndefined();
expect(JSON.parse(await readFile(statePath, 'utf8')).status).toBe('ok');
```

**Step 2: Implement state writing with atomic replace**

```ts
await writeFile(tempPath, JSON.stringify(state, null, 2), 'utf8');
await rename(tempPath, statePath);
```

**Step 3: Implement account and token file helpers**

Reuse the shared Battery layout under `~/.battery/`:

- read `accounts.json`
- resolve the selected account if one is marked or persisted
- load that account's token file from `~/.battery/tokens/`
- create missing directories before writing new state files
- preserve restrictive file permissions for account, token, and state files where applicable

**Step 4: Run storage tests**

Run: `cd port/core && npm test -- storage`

Expected: PASS

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: add selected-account, token, and state storage"
```

### Task 3: Implement token refresh and the usage API client

**Files:**
- Create: `port/core/src/auth/token-refresh.ts`
- Create: `port/core/src/api/anthropic-api.ts`
- Create: `port/core/src/api/api-errors.ts`
- Create: `port/core/test/auth/token-refresh.test.ts`
- Create: `port/core/test/api/anthropic-api.test.ts`
- Use: `port/fixtures/examples/usage-api/sample-200.json`
- Use: `port/fixtures/examples/usage-api/sample-401.json`
- Use: `port/fixtures/examples/usage-api/sample-429.json`

**Step 1: Write failing tests for refresh and API success behavior**

```ts
await expect(refreshIfNeeded(expiringTokens, refreshFetch)).resolves.toMatchObject({
  accessToken: expect.any(String),
});

expect(await fetchUsage(fetchMock, 'token')).toEqual(expect.objectContaining({
  sevenDay: expect.any(Object),
}));
```

**Step 2: Add refresh and API behavior to match Swift semantics**

Match Swift behavior for:

- refresh-near-expiry before polling
- force refresh after `401` when a refresh token exists
- `401` to unauthorized
- `429` to rate limited with optional retry delay
- other statuses to server errors

**Step 3: Add tests for the error cases**

```ts
await expect(refreshIfNeeded(tokensWithoutRefresh, refreshFetch)).rejects.toMatchObject({
  kind: 'no_refresh_token',
});

await expect(fetchUsage(fetch401, 'bad-token')).rejects.toMatchObject({
  kind: 'unauthorized',
});
```

Also add a test that a `401` polling path can succeed after a forced refresh returns new tokens.

**Step 4: Run auth and API tests**

Run: `cd port/core && npm test -- auth api`

Expected: PASS

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: add token refresh and anthropic usage api client"
```

### Task 4: Implement hook event reading and session reduction

**Files:**
- Create: `port/core/src/hooks/read-events.ts`
- Create: `port/core/src/hooks/session-reducer.ts`
- Create: `port/core/test/hooks/session-reducer.test.ts`
- Use: `port/fixtures/examples/hook-events/session-start-stop.jsonl`
- Use: `port/fixtures/examples/hook-events/idle-timeout.jsonl`

**Step 1: Write a failing session reducer test**

```ts
expect(reduceSessionState(events, now)).toEqual({
  isActive: false,
  currentSessionId: null,
});
```

**Step 2: Implement session state inference**

Match the Swift rules for:

- active session on `SessionStart`
- session end precedence
- idle timeout after recent activity
- startup replay from recent events
- basic file-safety parity for MVP: create missing event file path, reject symlink targets, and ignore malformed or oversized lines

**Step 3: Run hook tests**

Run: `cd port/core && npm test -- hooks`

Expected: PASS

**Step 4: Commit**

```bash
git add port/core
git commit -m "feat: add hook-based session state reduction"
```

### Task 5: Wire the reducer loop and emit usable state

**Files:**
- Create: `port/core/src/runtime/build-state.ts`
- Create: `port/core/src/runtime/poll-once.ts`
- Modify: `port/core/src/main.ts`
- Create: `port/core/test/runtime/poll-once.test.ts`

**Step 1: Write the failing end-to-end runtime test**

```ts
const state = await pollOnce({ fetchImpl, now, homeDir });
expect(state.status).toBe('ok');
expect(state.session?.utilization).toBeGreaterThanOrEqual(0);
expect(state.weekly?.utilization).toBeGreaterThanOrEqual(0);
expect(state.account?.isSelected).toBe(true);
expect(state.freshness.staleAfterSeconds).toBeGreaterThan(0);
```

Also assert that the emitted state parses with `batteryStateSchema`.

**Step 2: Implement the reducer pipeline**

Flow:

- load the selected account from shared Battery account storage
- load tokens
- refresh tokens when needed and persist replacements
- fetch usage
- read recent hook events
- build normalized state using the shared contract module from Plan B
- write `state.json`

**Step 3: Run the runtime tests**

Run: `cd port/core && npm test -- runtime`

Expected: PASS

**Step 4: Verify the output file and contract manually**

Run: `cd port/core && npm test`

Expected: PASS and no file-shape assertion failures.

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: emit normalized battery state from core"
```

### Task 6: Add the installed runtime path for GNOME MVP

**Files:**
- Create: `port/core/src/runtime/run-loop.ts`
- Create: `port/core/systemd/battery-core.service`
- Create: `port/core/test/runtime/run-loop.test.ts`
- Modify: `port/core/src/main.ts`

**Step 1: Write the failing service-oriented runtime test**

```ts
expect(getServiceCommand()).toContain('node');
expect(await runLoopTick(deps)).toMatchObject({
  wroteState: true,
});
```

**Step 2: Add the installed runtime path**

Implement:

- a long-running loop entry point suitable for `systemd --user`
- a checked-in user service unit that launches the core from the installed location
- restart behavior appropriate for a local background service
- a development path that can still run the same core loop in the foreground

**Step 3: Run runtime and service tests**

Run: `cd port/core && npm test -- runtime`

Expected: PASS

**Step 4: Commit**

```bash
git add port/core
git commit -m "feat: add installed runtime path for gnome core service"
```
