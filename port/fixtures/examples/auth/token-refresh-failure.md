# Token Refresh Failure Scenario

This fixture documents the expected behavior when OAuth token refresh fails on Linux.

## Trigger

`TokenRefreshService.forceRefresh()` returns a non-200 response, or
`TokenRefreshService.refreshIfNeeded()` finds no `refreshToken` (returns `noRefreshToken`).

## Response example (token endpoint, non-200)

```
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "invalid_grant",
  "error_description": "Refresh token has been revoked or expired."
}
```

## Expected behavior sequence

1. `UsagePollingService.pollNow()` catches `TokenRefreshService.TokenError`.
2. Sets `needsReauth = true`.
3. `UsageViewModel` observes `needsReauth` and calls `attemptSilentReauth()`.
4. Guard: `isReauthenticating` is set to `true` (prevents concurrent re-auth).
5. `error` is set to `"Session expired — signing in again…"` (visible in UI).
6. `OAuthService.startLogin()` opens the browser for a new OAuth flow.
7. If browser flow fails or times out (5-minute listener timeout):
   - `isReauthenticating = false`
   - `notificationService.notifyTokenRefreshFailure()` fires (debounced to 1h).
8. If browser flow succeeds:
   - New `StoredTokens` saved via `accountManager.saveTokens()`.
   - `error` cleared to `nil`.
   - `pollingService.configure()` called with new tokens.
   - Immediate `pollingService.pollNow()`.

## Linux port notes

- Browser launch: replace `NSWorkspace.shared.open(url)` with `xdg-open <url>`.
- Notification: replace `UNUserNotificationCenter` with `libnotify` / `notify-send`.
- All state transitions and debounce logic must match exactly.
