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

### Task 2: Implement token storage and state-file writing

**Files:**
- Create: `port/core/src/storage/token-store.ts`
- Create: `port/core/src/storage/state-store.ts`
- Create: `port/core/test/storage/token-store.test.ts`
- Create: `port/core/test/storage/state-store.test.ts`

**Step 1: Write failing tests for local storage behavior**

```ts
expect(await writeStateFile(tmpDir, state)).toBeUndefined();
expect(JSON.parse(await readFile(statePath, 'utf8')).status).toBe('ok');
```

**Step 2: Implement state writing with atomic replace**

```ts
await writeFile(tempPath, JSON.stringify(state, null, 2), 'utf8');
await rename(tempPath, statePath);
```

**Step 3: Implement token file helpers**

Store tokens under `~/.battery/tokens/` and create missing directories before writing.

**Step 4: Run storage tests**

Run: `cd port/core && npm test -- storage`

Expected: PASS

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: add core token and state storage"
```

### Task 3: Implement the usage API client

**Files:**
- Create: `port/core/src/api/anthropic-api.ts`
- Create: `port/core/src/api/api-errors.ts`
- Create: `port/core/test/api/anthropic-api.test.ts`
- Use: `port/fixtures/examples/usage-api/sample-200.json`
- Use: `port/fixtures/examples/usage-api/sample-401.json`
- Use: `port/fixtures/examples/usage-api/sample-429.json`

**Step 1: Write a failing test for the success response**

```ts
expect(await fetchUsage(fetchMock, 'token')).toEqual(expect.objectContaining({
  session: expect.any(Object),
}));
```

**Step 2: Add error mapping to match Swift semantics**

Map:

- `401` to unauthorized
- `429` to rate limited with optional retry delay
- other statuses to server errors

**Step 3: Add tests for the error cases**

```ts
await expect(fetchUsage(fetch401, 'bad-token')).rejects.toMatchObject({
  kind: 'unauthorized',
});
```

**Step 4: Run API tests**

Run: `cd port/core && npm test -- api`

Expected: PASS

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: add anthropic usage api client"
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
```

**Step 2: Implement the reducer pipeline**

Flow:

- load tokens
- fetch usage
- read recent hook events
- build normalized state
- write `state.json`

**Step 3: Run the runtime tests**

Run: `cd port/core && npm test -- runtime`

Expected: PASS

**Step 4: Verify the output file manually**

Run: `cd port/core && npm test`

Expected: PASS and no file-shape assertion failures.

**Step 5: Commit**

```bash
git add port/core
git commit -m "feat: emit normalized battery state from core"
```
