# Battery Compatibility Verification Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Verify that the new TypeScript core reproduces the important behavior of the Swift Battery implementation.

**Architecture:** Use fixtures, golden-style assertions, and parity-focused tests rather than broad integration guesswork. The verification layer should compare inputs and outputs domain by domain and make drift obvious.

**Tech Stack:** TypeScript, npm, Vitest, JSON fixtures, Markdown parity inventory

---

### Task 1: Create the compatibility test harness

**Files:**
- Create: `port/core/test/compat/compat-test-harness.ts`
- Create: `port/core/test/compat/session-parity.test.ts`
- Create: `port/core/test/compat/usage-parity.test.ts`
- Create: `port/core/test/compat/contract-parity.test.ts`
- Modify: `port/core/package.json`

**Step 1: Add a focused compat test script**

```json
{
  "scripts": {
    "test:compat": "vitest run test/compat"
  }
}
```

**Step 2: Write the first failing parity test**

```ts
import { describe, expect, it } from 'vitest';
import { loadHookFixture } from './compat-test-harness.js';
import { reduceSessionState } from '../../src/hooks/session-reducer.js';

describe('session parity', () => {
  it('matches the expected active-session result from the Swift fixture note', async () => {
    const fixture = await loadHookFixture('session-start-stop.jsonl');
    const state = reduceSessionState(fixture.events, fixture.now);

    expect(state.isActive).toBe(false);
  });
});
```

**Step 3: Run test to verify it fails**

Run: `cd port/core && npm run test:compat`

Expected: FAIL until the harness exists and fixtures are wired.

**Step 4: Commit**

```bash
git add port/core
git commit -m "test: add compatibility verification harness"
```

### Task 2: Add session, usage, and contract parity fixtures

**Files:**
- Create: `port/fixtures/compat/session/start-stop.expected.json`
- Create: `port/fixtures/compat/session/idle-timeout.expected.json`
- Create: `port/fixtures/compat/usage/sample-200.expected.json`
- Create: `port/fixtures/compat/contract/ok-state.expected.json`
- Create: `port/fixtures/compat/contract/login-required.expected.json`
- Modify: `port/core/test/compat/session-parity.test.ts`
- Modify: `port/core/test/compat/usage-parity.test.ts`
- Modify: `port/core/test/compat/contract-parity.test.ts`

**Step 1: Write expected outputs from the parity inventory**

Example expected session file:

```json
{
  "isActive": false,
  "currentSessionId": null
}
```

**Step 2: Compare reducer output against the expected files**

```ts
expect(state).toMatchObject(expected);
```

For contract parity, compare the emitted `pollOnce` result against expected JSON and assert that the final state also parses with `batteryStateSchema`.

The MVP contract fixture set must cover:

- selected-account metadata
- `updatedAt`
- weekly state
- `freshness.staleAfterSeconds`
- login-required output when no usable account or tokens are present

**Step 3: Run compatibility tests**

Run: `cd port/core && npm run test:compat`

Expected: PASS

**Step 4: Commit**

```bash
git add port/core port/fixtures/compat
git commit -m "test: add session, usage, and contract parity fixtures"
```

### Task 3: Add error and auth behavior parity tests

**Files:**
- Create: `port/fixtures/compat/errors/unauthorized.expected.json`
- Create: `port/fixtures/compat/errors/rate-limited.expected.json`
- Create: `port/fixtures/compat/errors/refresh-after-401.expected.json`
- Create: `port/fixtures/compat/errors/no-refresh-token.expected.json`
- Create: `port/core/test/compat/error-parity.test.ts`

**Step 1: Add tests that lock in Swift-style API error mapping**

```ts
await expect(fetchUsage(fetch401, 'bad')).rejects.toMatchObject({
  kind: 'unauthorized',
});
```

**Step 2: Add the `429` parity check**

```ts
await expect(fetchUsage(fetch429, 'token')).rejects.toMatchObject({
  kind: 'rate_limited',
  retryAfterSeconds: 30,
});
```

**Step 3: Add auth lifecycle parity checks**

Verify parity for:

- refresh-near-expiry before polling
- forced refresh after `401` when a refresh token exists
- login-required output when refresh is impossible

Example:

```ts
const state = await pollOnce({ fetchImpl, refreshFetchImpl, now, homeDir });

expect(state).toMatchObject({
  status: 'ok',
  account: { isSelected: true },
});
```

**Step 4: Run compatibility tests**

Run: `cd port/core && npm run test:compat`

Expected: PASS

**Step 5: Commit**

```bash
git add port/core port/fixtures/compat/errors
git commit -m "test: lock in swift auth and error parity"
```

### Task 4: Add session and usage edge-case parity tests

**Files:**
- Create: `port/fixtures/compat/session/malformed-line-ignored.expected.json`
- Create: `port/fixtures/compat/session/oversized-line-ignored.expected.json`
- Create: `port/fixtures/compat/session/startup-replay.expected.json`
- Modify: `port/core/test/compat/session-parity.test.ts`
- Modify: `port/core/test/compat/usage-parity.test.ts`

**Step 1: Add the session edge-case fixtures from the parity inventory**

Cover:

- startup replay from recent events
- malformed event lines ignored
- oversized event lines ignored

**Step 2: Extend usage parity assertions**

Lock in the MVP-required usage fields only:

- session utilization and reset time
- weekly utilization and reset time
- plan tier when present

Do not require deferred fields such as `opus`, `sonnet`, or `extraUsage` in MVP compat tests.

**Step 3: Run compatibility tests**

Run: `cd port/core && npm run test:compat`

Expected: PASS

**Step 4: Commit**

```bash
git add port/core port/fixtures/compat
git commit -m "test: add session and usage edge-case parity coverage"
```

### Task 5: Add the parity checklist report

**Files:**
- Create: `port/fixtures/compat/PARITY_CHECKLIST.md`

**Step 1: Write the report format**

```md
# Parity Checklist

- [ ] Contract output parses with `batteryStateSchema`
- [ ] Selected-account metadata is preserved
- [ ] Login-required state when account or tokens are missing
- [ ] Session activity inference
- [ ] Startup replay from recent events
- [ ] Idle timeout handling
- [ ] Unauthorized error mapping
- [ ] Forced refresh after `401`
- [ ] Rate limit retry-after mapping
- [ ] Session utilization normalization
- [ ] Weekly utilization normalization
- [ ] `updatedAt` and freshness semantics
- [ ] Plan tier parity when present
```

**Step 2: Update the checklist only when a compat test exists and passes**

Add a rule at the top of the file:

```md
Only check an item when there is an automated test covering it.
```

Also add one note:

```md
Deferred fields such as `opus`, `sonnet`, `extraUsage`, and projection behavior stay unchecked until those domains enter the Linux MVP contract.
```

**Step 3: Commit**

```bash
git add port/fixtures/compat/PARITY_CHECKLIST.md
git commit -m "docs: add parity verification checklist"
```
