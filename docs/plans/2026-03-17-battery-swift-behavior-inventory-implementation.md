# Battery Swift Behavior Inventory Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract the proven Battery behavior from the Swift app into a concrete parity inventory that the TypeScript port must follow.

**Architecture:** Treat the existing Swift files as the behavioral oracle. Capture the important state transitions, inputs, outputs, edge cases, and fixture candidates in explicit artifacts under `port/fixtures/` so later plans can port behavior without redesigning it.

**Tech Stack:** Markdown, Swift source analysis, JSON fixtures

---

### Task 1: Create the parity inventory skeleton

**Files:**
- Create: `port/fixtures/README.md`
- Create: `port/fixtures/swift-parity-matrix.md`
- Create: `port/fixtures/swift-domains/session-state.md`
- Create: `port/fixtures/swift-domains/usage-metrics.md`
- Create: `port/fixtures/swift-domains/errors-and-auth.md`

**Step 1: Create the fixtures directory skeleton**

```text
port/
port/fixtures/
port/fixtures/swift-domains/
```

**Step 2: Write the top-level fixtures README**

```md
# Battery Port Fixtures

This directory stores the behavioral reference material for the Linux port.

- `swift-parity-matrix.md` tracks what must match the Swift app
- `swift-domains/` stores domain-by-domain behavior notes
```

**Step 3: Write the parity matrix shell**

```md
# Swift Parity Matrix

| Domain | Swift Source | Required Parity | Notes |
| --- | --- | --- | --- |
| Session state | `Sources/Services/HookFileWatcher.swift` | Yes | |
| Usage metrics | `Sources/ViewModels/UsageViewModel.swift` | Yes | |
| Errors and auth | `Sources/Services/AnthropicAPI.swift` | Yes | |
```

**Step 4: Commit**

```bash
git add port/fixtures
git commit -m "docs: add swift parity inventory skeleton"
```

### Task 2: Document session and polling behavior

**Files:**
- Modify: `port/fixtures/swift-parity-matrix.md`
- Modify: `port/fixtures/swift-domains/session-state.md`
- Create: `port/fixtures/examples/hook-events/session-start-stop.jsonl`
- Create: `port/fixtures/examples/hook-events/idle-timeout.jsonl`

**Step 1: Capture the session rules from Swift**

Document these items from `Sources/Services/HookFileWatcher.swift`:

- event types that activate a session
- idle timeout behavior
- session start and end precedence
- file safety assumptions

**Step 2: Save representative event fixtures**

```json
{"event":"SessionStart","timestamp":"2026-03-17T08:00:00Z","sessionId":"abc"}
{"event":"PostToolUse","timestamp":"2026-03-17T08:01:00Z","sessionId":"abc","tool":"Read"}
{"event":"SessionEnd","timestamp":"2026-03-17T08:10:00Z","sessionId":"abc"}
```

**Step 3: Update the parity matrix row notes**

```md
| Session state | `Sources/Services/HookFileWatcher.swift` | Yes | Match event ordering, idle timeout, and active-session inference on startup |
```

**Step 4: Commit**

```bash
git add port/fixtures
git commit -m "docs: document swift session behavior"
```

### Task 3: Document usage, projection, and threshold behavior

**Files:**
- Modify: `port/fixtures/swift-parity-matrix.md`
- Modify: `port/fixtures/swift-domains/usage-metrics.md`
- Create: `port/fixtures/examples/usage-api/sample-200.json`
- Create: `port/fixtures/examples/usage-api/sample-429.json`
- Create: `port/fixtures/examples/usage-api/sample-401.json`

**Step 1: Trace usage state rules from Swift**

Document these items from:

- `Sources/ViewModels/UsageViewModel.swift`
- `Sources/Utilities/BurnRateCalculator.swift`
- `Sources/Utilities/TimeFormatting.swift`
- `Sources/Utilities/ColorThresholds.swift`

**Step 2: Record required outputs**

```md
- session utilization rounding behavior
- weekly utilization handling
- reset-time derived values
- burn-rate projection inputs and outputs
- threshold crossing semantics
```

**Step 3: Save representative API fixtures**

Store raw success and error responses in `port/fixtures/examples/usage-api/`.

**Step 4: Commit**

```bash
git add port/fixtures
git commit -m "docs: document swift usage behavior"
```

### Task 4: Document auth and error handling behavior

**Files:**
- Modify: `port/fixtures/swift-parity-matrix.md`
- Modify: `port/fixtures/swift-domains/errors-and-auth.md`
- Create: `port/fixtures/examples/auth/token-refresh-failure.md`

**Step 1: Capture auth behavior from Swift**

Document these files:

- `Sources/Services/OAuthService.swift`
- `Sources/Services/TokenRefreshService.swift`
- `Sources/Services/AnthropicAPI.swift`
- `Sources/Services/NotificationService.swift`

**Step 2: Record the Linux-port parity boundary**

```md
- Keep token semantics and retry behavior aligned
- Allow browser-opening and notification mechanisms to differ by platform
```

**Step 3: Final review**

Read `port/fixtures/swift-parity-matrix.md` top to bottom and ensure every domain has:

- source file
- parity requirement
- allowed differences
- at least one fixture candidate

**Step 4: Commit**

```bash
git add port/fixtures
git commit -m "docs: finish swift behavior inventory"
```
