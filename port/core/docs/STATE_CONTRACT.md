# Battery State Contract

The GNOME extension may safely rely on:

- `status`
- `updatedAt`
- `account.id`
- `account.name`
- `account.planTier`
- `session.utilization`
- `session.resetsAt`
- `session.isActive`
- `weekly.utilization`
- `weekly.resetsAt`
- `freshness.staleAfterSeconds`
- `error.kind`

## Versioning Rules

- Increment `version` only for breaking changes
- Additive fields must be optional first
- The MVP contract represents one selected account only
- Deferred parity fields are tracked separately until they are implemented
- The extension must treat state older than the freshness window as stale
