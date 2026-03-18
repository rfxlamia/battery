# Swift Parity Matrix

| Domain | Swift Source | Required Parity | Notes |
| --- | --- | --- | --- |
| Session state | `Sources/Services/HookFileWatcher.swift` | Yes | Match event ordering, idle timeout (300s), and active-session inference on startup |
| Usage metrics | `Sources/ViewModels/UsageViewModel.swift` | Yes | Match utilization fields, burn-rate regression, threshold/debounce values, time formatting |
| Errors and auth | `Sources/Services/AnthropicAPI.swift` | Yes | Match token refresh buffer, 401 retry, rate-limit backoff (60s base, 600s max); browser/notification/storage backends may differ |
