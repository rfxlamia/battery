# Errors and Auth — Swift Behavior Reference

Sources:
- `Sources/Services/OAuthService.swift`
- `Sources/Services/TokenRefreshService.swift`
- `Sources/Services/AnthropicAPI.swift`
- `Sources/Services/NotificationService.swift`

---

## OAuth Login Flow (`OAuthService.swift`)

The Swift app uses **OAuth 2.0 with PKCE** (Proof Key for Code Exchange):

1. Generate a 32-byte random `code_verifier` (base64url-encoded).
2. Derive `code_challenge = SHA256(code_verifier)` (base64url-encoded, S256 method).
3. Start a local HTTP server on a random `localhost` port (IPv6 dual-stack, `SO_REUSEADDR`).
4. Open the browser to the Anthropic OAuth authorize URL with query params:
   `client_id`, `redirect_uri` (`http://localhost:<port>/callback`), `response_type=code`,
   `scope`, `code_challenge`, `code_challenge_method=S256`, `state`.
5. Receive the authorization `code` via the local HTTP server callback.
6. Exchange code for tokens via POST to token endpoint with:
   `grant_type=authorization_code`, `code`, `client_id`, `code_verifier`, `redirect_uri`, `state`.
7. Token response: `access_token`, `refresh_token` (optional), `expires_in` (defaults to `3600` if absent).

### Local server safety

- Listener auto-stops after **300 seconds** (5 minutes) to prevent leaked listeners.
- Only the first valid `code` query parameter is processed; subsequent requests get `"Waiting for auth..."`.

### Allowed Linux differences

- Browser opening uses `NSWorkspace.shared.open(url)` on macOS.
  On Linux, use `xdg-open` or `gio open` (or equivalent).
- The local callback server implementation will differ (no `SocketFD`/Darwin raw sockets needed — use standard library).
- Token exchange and PKCE logic must be preserved exactly.

---

## Token Storage (`StoredTokens`)

- Stored per account in `AccountManager` (backed by macOS Keychain on Swift).
- Fields: `accessToken`, `refreshToken` (optional), `expiresIn` → used to compute `expiryDate`.

### Allowed Linux differences

- Storage backend: use `libsecret` / `secret-tool` / encrypted file instead of Keychain.
- Token semantics (expiry, fields) must be preserved exactly.

---

## Token Refresh (`TokenRefreshService.swift`)

### Proactive refresh

`refreshIfNeeded(tokens:)` is called before every API request:
- If `expiryDate - now > 300s` (5-minute buffer) → return existing access token unchanged.
- If within buffer: POST `grant_type=refresh_token` with `refresh_token`, `client_id`, `scope`.
- On success: update `accessToken`, optionally update `refreshToken` (new value if provided, else keep old).

### Force refresh (on 401)

`forceRefresh(refreshToken:)` skips the expiry check and always performs the refresh POST.
Called by `UsagePollingService.retryWithForceRefresh()` when a 401 is received.

### Error types

| Error | Description |
| --- | --- |
| `noRefreshToken` | `refreshToken` is nil — triggers `needsReauth = true` |
| `refreshFailed(statusCode, body)` | Non-200 response from token endpoint |
| `networkError(Error)` | Network-level failure during token refresh |

---

## API Error Handling (`AnthropicAPI.swift`)

### Error types

| HTTP status | Error | Behavior |
| --- | --- | --- |
| 200 | (none) | Decode `UsageResponse` |
| 401 | `unauthorized` | `isUnauthorized = true` → triggers force refresh retry |
| 429 | `rateLimited(retryAfter:)` | `Retry-After` header parsed as `TimeInterval`; rate limit headers logged to `~/.battery/rate-limits.log` |
| other | `serverError(statusCode, body)` | Treated as permanent error |
| (decode fails) | `decodingError(Error)` | Treated as permanent error |
| (network failure) | `networkError(Error)` | Treated as permanent error |

### Rate limit behavior in `UsagePollingService`

- On 429: increment `consecutiveRateLimits`; do NOT overwrite `lastError` if `latestUsage` already exists (cached data preserved).
- Backoff: `effectiveInterval = min(baseBackoffInterval * 2^(consecutiveRateLimits - 1), maxBackoffInterval)`
  where `baseBackoffInterval = 60s` and `maxBackoffInterval = 600s`.
- On success: `consecutiveRateLimits` resets to 0.

### 401 retry sequence

1. 401 received → `retryWithForceRefresh()` called.
2. Force-refresh token.
3. Retry `fetchUsage` with new access token.
4. If force-refresh also fails → `needsReauth = true` (triggers silent re-auth flow in `UsageViewModel`).

### Timeout

API requests have a 15-second timeout (`request.timeoutInterval = 15`).

---

## Silent Re-auth Flow (`UsageViewModel.swift`)

When `needsReauth` fires from `UsagePollingService`:
1. Guard: only one re-auth at a time (`isReauthenticating`).
2. Set `error = "Session expired — signing in again…"`.
3. Start `OAuthService.startLogin()` (opens browser).
4. On success: replace tokens for current account, clear error, restart polling.
5. On failure: call `notificationService.notifyTokenRefreshFailure()`.

### Token refresh failure notification

- Title: `"Credentials Need Attention"`
- Body: `"Battery couldn't refresh your token. Please sign in again from Battery."`
- Debounce: 3600 seconds (1 hour).

---

## Linux Port Parity Boundary

| Concern | Must match | May differ |
| --- | --- | --- |
| Token semantics (expiry, fields, refresh buffer) | Yes | — |
| PKCE OAuth token exchange logic | Yes | — |
| Retry on 401 (force refresh, then reauth) | Yes | — |
| Rate limit backoff (base 60s, max 600s, exponential) | Yes | — |
| API request timeout (15s) | Yes | — |
| Notification debounce intervals | Yes | — |
| Browser opening for OAuth | — | `xdg-open` instead of `NSWorkspace` |
| Notification delivery | — | `libnotify`/DBus instead of `UNUserNotificationCenter` |
| Token storage | — | `libsecret` instead of Keychain |
| Local OAuth callback server implementation | — | Standard library sockets instead of Darwin raw sockets |
