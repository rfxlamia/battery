# Usage Metrics — Swift Behavior Reference

Sources:
- `Sources/ViewModels/UsageViewModel.swift`
- `Sources/Utilities/BurnRateCalculator.swift`
- `Sources/Utilities/TimeFormatting.swift`
- `Sources/Utilities/ColorThresholds.swift`

---

## Session Utilization

- Sourced from `UsageResponse.fiveHour.utilization` (a `Double`, 0–100).
- If `fiveHour` is `nil` (no active 5-hour window), `sessionUtilization` is set to `0`.
- `sessionResetsAt` is derived from `UsageResponse.fiveHour.resetsAtDate`.
- When `fiveHour` is `nil`, `projection` is cleared to `nil`.

## Weekly Utilization

- Sourced from `UsageResponse.sevenDay.utilization`.
- Always present (non-optional) unlike `fiveHour`.
- `weeklyResetsAt` from `UsageResponse.sevenDay.resetsAtDate`.

## Per-model Utilization (optional fields)

- `sonnetUtilization` from `UsageResponse.sevenDaySonnet?.utilization`
- `opusUtilization` from `UsageResponse.sevenDayOpus?.utilization`
- Both are `Double?` — `nil` when absent in the API response.

## Extra Usage

- `extraUsageEnabled` = `usage.extraUsage?.isEnabled ?? false`
- `extraUsageCost` = `usage.extraUsage?.usedCredits` (optional)
- `extraUsageLimit` = `usage.extraUsage?.monthlyLimit` (optional)
- `extraUsageUtilization` = `usage.extraUsage?.utilization` (optional)

---

## Time Remaining

- `sessionTimeRemaining = max(0, sessionResetsAt.timeIntervalSinceNow)` — clamped to zero.
- `weeklyTimeRemaining = max(0, weeklyResetsAt.timeIntervalSinceNow)` — clamped to zero.

---

## Time Formatting (`TimeFormatting.swift`)

### `shortDuration(_ interval: TimeInterval) -> String`

| Input | Output |
| --- | --- |
| `<= 0` | `"0s"` |
| hours > 0 | `"\(h)h \(m)m"` (e.g. `"2h 13m"`) |
| minutes > 0, hours == 0 | `"\(m)m"` (e.g. `"45m"`) |
| seconds > 0, minutes == 0 | `"\(s)s"` (e.g. `"30s"`) |
| exactly 0 | `"< 1m"` (unreachable in practice — guarded by `<= 0` above) |

### `relativeTime(_ date: Date) -> String`

| Elapsed | Output |
| --- | --- |
| < 60s | `"just now"` |
| < 3600s | `"\(m)m ago"` |
| < 86400s | `"\(h)h ago"` |
| >= 86400s | `"\(d)d ago"` |

### Menu bar time display

When `showTimeSinceReset` is enabled:
- elapsed = `18000 - max(0, resetsAt.timeIntervalSinceNow)` (5-hour window = 18 000 s)
- displayed as `shortDuration(max(0, elapsed))`

---

## Color Thresholds (`ColorThresholds.swift` → `UsageLevel`)

| Utilization range | Level | Classic color | Default theme |
| --- | --- | --- | --- |
| 0 – < 50% | `low` | green | brand |
| 50 – < 75% | `moderate` | yellow | brand |
| 75 – < 90% | `high` | orange | brandDark |
| 90%+ | `critical` | red | brandDark |

Threshold boundaries: `<50`, `50..<75`, `75..<90`, `>=90`.

SF Symbol per level: `battery.75percent` (low), `battery.50percent` (moderate),
`battery.25percent` (high), `battery.25percent` (critical).

---

## Burn Rate Projection (`BurnRateCalculator.swift`)

### Inputs

- `snapshots`: recent `UsageSnapshot` records (up to 20, from SQLite).
- `currentUtilization`: latest session utilization (Double, 0–100).
- `resetsAt`: the current session reset time.

### Session window filtering

Snapshots are filtered to those whose `sessionResetsAt` is within **1 second** of `resetsAt`.
This discards snapshots from previous sessions, which would corrupt the regression.

### Minimum data requirements

| Requirement | Value |
| --- | --- |
| Minimum snapshots | 3 |
| Minimum time span between first and last snapshot | 120 seconds (2 minutes) |

If either threshold is not met, returns `insufficientData(at: currentUtilization)`:
`currentRate=0`, `projectedLimitTime=nil`, `projectedAtReset=currentUtilization`, `hasEnoughData=false`.

### Linear regression

- `x` = time in hours since first snapshot's timestamp (origin = 0).
- `y` = `sessionUtilization`.
- Standard OLS: `slope = (n*sumXY - sumX*sumY) / (n*sumX2 - sumX^2)`.
- Slope is **clamped to zero** (`max(0, rawSlope)`) — utilization can only increase within a window.
- Denominator guard: `abs(denominator) <= 1e-10` → `insufficientData`.

### Trend classification

| Slope | Trend |
| --- | --- |
| > 1.0 %/h | `increasing` |
| <= 1.0 %/h | `stable` |

Note: there is no `decreasing` trend case assigned by the calculator (slope is clamped to >= 0).

### Projected limit time

Only computed when `slope > 0.01` and `currentUtilization < 100`:
```
hoursToLimit = (100 - currentUtilization) / slope
projectedLimitTime = now + hoursToLimit * 3600
```

### Projected utilization at reset

```
hoursToReset = max(0, resetsAt.timeIntervalSinceNow / 3600)
projectedAtReset = clamp(0, 100, currentUtilization + slope * hoursToReset)
```

---

## Today Peak Tracking

- `todayPeakSeen` tracks the highest `sessionUtilization` seen today.
- Resets at calendar day boundary.
- Injected into `activeDays` and `dailyPeaks` for heatmap and sparkline display.
- Injection only occurs when `isConnected && todayPeakSeen > 0` and today has no entry yet.

---

## Notification Thresholds (`NotificationService.swift`)

Configurable thresholds: 80%, 90%, 95% (each individually enabled/disabled in settings).

- A threshold fires once per crossing (tracked in `notifiedThresholds`).
- Debounce per threshold: 3600 seconds (1 hour) — won't re-fire within the hour even if
  the session resets and crosses again.
- On **session reset** (previous > 30% → current < 10%): all threshold state is cleared,
  5-minute debounce on the reset notification itself.
- `resetThresholds(below:)` removes thresholds above the current value (e.g. on utilization drop).

### Projection notification

- Fires when `projectedLimitTime` is within 30 minutes **and** the limit is before the session reset.
- Debounce: 1800 seconds (30 minutes).

### Credential notification

- Fires when silent re-auth fails.
- Debounce: 3600 seconds (1 hour).

---

## Allowed Differences in Linux Port

- SF symbols and SwiftUI `Color` are macOS-only — use equivalent system/CSS color values.
- Notification delivery mechanism differs (DBus / libnotify on Linux vs. `UNUserNotificationCenter`).
- All numeric thresholds, debounce intervals, and calculation logic must be preserved exactly.
