# Battery Shared Contract Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Define a stable local state contract that the TypeScript core produces and the GNOME extension consumes.

**Architecture:** Create a small contract module inside the new TypeScript core area. The contract should model the proven Swift behavior while staying runtime-safe through schema validation and versioned state output.

**Tech Stack:** TypeScript, npm, Zod, Vitest

---

### Task 1: Bootstrap the contract workspace

**Files:**
- Create: `port/core/package.json`
- Create: `port/core/tsconfig.json`
- Create: `port/core/vitest.config.ts`
- Create: `port/core/src/index.ts`
- Create: `port/core/src/contracts/index.ts`
- Create: `port/core/test/contracts/state-contract.test.ts`

**Step 1: Write the package manifest**

```json
{
  "name": "@battery/core",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "devDependencies": {
    "typescript": "^5.9.0",
    "vitest": "^3.2.0",
    "zod": "^4.1.0"
  }
}
```

**Step 2: Write the first failing contract test**

```ts
import { describe, expect, it } from 'vitest';
import { batteryStateSchema } from '../../src/contracts/index.js';

describe('batteryStateSchema', () => {
  it('accepts the minimal disconnected state', () => {
    const result = batteryStateSchema.safeParse({
      version: 1,
      status: 'login_required',
      updatedAt: '2026-03-17T00:00:00.000Z',
    });

    expect(result.success).toBe(true);
  });
});
```

**Step 3: Run test to verify it fails**

Run: `cd port/core && npm test -- --runInBand`

Expected: FAIL because `batteryStateSchema` does not exist yet.

**Step 4: Commit**

```bash
git add port/core
git commit -m "build: bootstrap shared contract workspace"
```

### Task 2: Define the core state schema

**Files:**
- Create: `port/core/src/contracts/state.ts`
- Modify: `port/core/src/contracts/index.ts`
- Modify: `port/core/test/contracts/state-contract.test.ts`

**Step 1: Implement the runtime schema**

```ts
import { z } from 'zod';

export const batteryStateSchema = z.object({
  version: z.literal(1),
  status: z.enum(['ok', 'loading', 'login_required', 'error']),
  updatedAt: z.string(),
  account: z.object({
    id: z.string(),
    name: z.string(),
    planTier: z.string(),
  }).optional(),
  session: z.object({
    utilization: z.number(),
    resetsAt: z.string().nullable(),
    isActive: z.boolean(),
  }).optional(),
});
```

**Step 2: Expand tests for the happy path and error path**

```ts
it('rejects an unknown status', () => {
  const result = batteryStateSchema.safeParse({
    version: 1,
    status: 'mystery',
    updatedAt: '2026-03-17T00:00:00.000Z',
  });

  expect(result.success).toBe(false);
});
```

**Step 3: Run the tests**

Run: `cd port/core && npm test`

Expected: PASS

**Step 4: Commit**

```bash
git add port/core
git commit -m "feat: add shared battery state schema"
```

### Task 3: Add domain-specific contract modules

**Files:**
- Create: `port/core/src/contracts/session.ts`
- Create: `port/core/src/contracts/usage.ts`
- Create: `port/core/src/contracts/errors.ts`
- Modify: `port/core/src/contracts/state.ts`
- Create: `port/core/test/contracts/domain-contracts.test.ts`

**Step 1: Move nested schemas into focused modules**

Create separate schemas for:

- session state
- usage metrics
- auth and API errors

**Step 2: Add tests for optional but structured fields**

```ts
expect(batteryStateSchema.parse({
  version: 1,
  status: 'error',
  updatedAt: '2026-03-17T00:00:00.000Z',
  error: {
    kind: 'rate_limited',
    message: 'Rate limited',
  },
})).toBeDefined();
```

**Step 3: Run the tests**

Run: `cd port/core && npm test`

Expected: PASS

**Step 4: Commit**

```bash
git add port/core
git commit -m "feat: split shared contract into domain schemas"
```

### Task 4: Write the contract usage note for the GNOME extension

**Files:**
- Create: `port/core/src/contracts/STATE_CONTRACT.md`

**Step 1: Document the stable fields the extension can rely on**

```md
# Battery State Contract

The GNOME extension may safely rely on:

- `status`
- `updatedAt`
- `session.utilization`
- `session.resetsAt`
- `session.isActive`
- `weekly.utilization`
- `error.kind`
```

**Step 2: Document versioning rules**

```md
- Increment `version` only for breaking changes
- Additive fields must be optional first
```

**Step 3: Commit**

```bash
git add port/core/src/contracts/STATE_CONTRACT.md
git commit -m "docs: document shared contract rules"
```
