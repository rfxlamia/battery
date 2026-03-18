# Session State — Swift Behavior Reference

Source: `Sources/Services/HookFileWatcher.swift`

---

## Event Types

The watcher processes events from `~/.battery/events.jsonl` (append-only JSONL file).

| Event type | Effect |
| --- | --- |
| `SessionStart` | `isSessionActive = true`; sets `currentSessionStart` and `currentSessionId` from event |
| `SessionEnd` | `isSessionActive = false`; clears `currentSessionStart` and `currentSessionId` |
| `PostToolUse` | If session not active, activates it (uses existing `currentSessionStart` or event timestamp); resets idle timer |
| `stop` | Same as `PostToolUse` |

All events update `lastActivity = Date()` (wall clock, not event timestamp).

---

## Idle Timeout

- **Idle timeout:** 300 seconds (5 minutes)
- A periodic timer fires every 60 seconds and calls `checkIdle()`.
- `checkIdle()`: if `isSessionActive && now - lastActivity >= 300s`, clears session state.
- `resetIdleTimer()` does nothing structurally — idle is checked by the timer interval, not by resetting a countdown. The guard is purely via `lastActivity`.

---

## Startup / State Recovery

On `startWatching()`, the watcher reads the **last 20 lines** of the events file to infer current state:

1. Walk lines, tracking `latestSessionStart`, `latestSessionEnd`, `latestActivity`.
2. If a `SessionStart` exists:
   - If `SessionEnd.timestamp >= SessionStart.timestamp` → session is inactive.
   - Else → compute `mostRecentTime = latestActivity?.timestamp ?? SessionStart.timestamp`.
     - If `now - mostRecentTime < 300s` → session is active; restore `currentSessionStart` and `currentSessionId`.
     - Else → session is idle, inactive.
3. File is opened and seeked to end so only **new** events are processed at runtime.

---

## File Safety Assumptions

- Directory `~/.battery/` is created with permissions `0700` if missing.
- File `~/.battery/events.jsonl` is created with permissions `0600` if missing.
- **Symlink protection:** the watcher refuses to open or read the file if it is a symlink (`lstat` check).
- Symlink check is performed on both `startWatching()` and `parseRecentEvents()`.

---

## Input Validation (per event line)

| Rule | Value |
| --- | --- |
| Max line length | 4096 bytes — lines over limit are silently dropped |
| Rate limit | Max 50 events per second; excess events in the same second are dropped |
| Timestamp staleness | Events with `abs(timestamp - now) >= 3600s` (1 hour) are dropped |
| `sessionId` max length | 128 characters |
| `tool` max length | 256 characters |

---

## Polling Rate Integration

`UsageViewModel` observes `hookWatcher.$isSessionActive` and calls `pollingService.setInterval()`:

- Session active → `AppSettings.pollIntervalActive`
- Session idle → `AppSettings.pollIntervalIdle`

---

## Allowed Differences in Linux Port

- File-watching mechanism: `DispatchSourceFileSystemObject` (macOS-only) must be replaced with `inotify` or polling on Linux.
- All behavioral rules (idle timeout, startup recovery, event ordering, validation limits) must be preserved exactly.
