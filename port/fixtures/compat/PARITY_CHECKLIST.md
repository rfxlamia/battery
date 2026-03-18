# Parity Checklist

Only check an item when there is an automated test covering it.

Deferred fields such as `opus`, `sonnet`, `extraUsage`, and projection behavior stay unchecked until those domains enter the Linux MVP contract.

- [x] Contract output parses with `batteryStateSchema` — [contract-parity.test.ts](../../core/test/compat/contract-parity.test.ts)
- [x] Selected-account metadata is preserved — [contract-parity.test.ts](../../core/test/compat/contract-parity.test.ts)
- [x] Login-required state when account or tokens are missing — [contract-parity.test.ts](../../core/test/compat/contract-parity.test.ts)
- [x] Session activity inference — [session-parity.test.ts](../../core/test/compat/session-parity.test.ts)
- [x] Startup replay from recent events — [session-parity.test.ts](../../core/test/compat/session-parity.test.ts)
- [x] Idle timeout handling — [session-parity.test.ts](../../core/test/compat/session-parity.test.ts)
- [x] Unauthorized error mapping — [error-parity.test.ts](../../core/test/compat/error-parity.test.ts)
- [x] Forced refresh after `401` — [error-parity.test.ts](../../core/test/compat/error-parity.test.ts)
- [x] Rate limit retry-after mapping — [error-parity.test.ts](../../core/test/compat/error-parity.test.ts)
- [x] Session utilization normalization — [usage-parity.test.ts](../../core/test/compat/usage-parity.test.ts)
- [x] Weekly utilization normalization — [usage-parity.test.ts](../../core/test/compat/usage-parity.test.ts)
- [x] `updatedAt` and freshness semantics — [contract-parity.test.ts](../../core/test/compat/contract-parity.test.ts), [usage-parity.test.ts](../../core/test/compat/usage-parity.test.ts)
- [x] Plan tier parity when present — [usage-parity.test.ts](../../core/test/compat/usage-parity.test.ts)
- [x] Malformed event lines ignored — [session-parity.test.ts](../../core/test/compat/session-parity.test.ts)
- [x] Oversized event lines ignored — [session-parity.test.ts](../../core/test/compat/session-parity.test.ts)
- [x] Refresh near-expiry before polling — [error-parity.test.ts](../../core/test/compat/error-parity.test.ts)
- [x] Login-required when no refresh token — [error-parity.test.ts](../../core/test/compat/error-parity.test.ts)
