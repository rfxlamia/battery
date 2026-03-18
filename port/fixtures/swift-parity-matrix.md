# Swift Parity Matrix

| Domain | Swift Source | Required Parity | Notes | Allowed Differences |
| --- | --- | --- | --- | --- |
| Session state | `Sources/Services/HookFileWatcher.swift` | Yes | Match event ordering, idle timeout (300s), and active-session inference on startup | File-watching mechanism (inotify on Linux) |
| Usage metrics | `Sources/ViewModels/UsageViewModel.swift` | Yes | Match utilization fields, burn-rate regression, threshold/debounce values, time formatting | Notification delivery (libnotify/DBus), color/symbol rendering |
| Errors and auth | `Sources/Services/AnthropicAPI.swift` | Yes | Match token refresh buffer (300s), 401 retry, rate-limit backoff (60s base, 600s max) | Browser launch (xdg-open), token storage (libsecret), notification delivery, OAuth callback server implementation |
