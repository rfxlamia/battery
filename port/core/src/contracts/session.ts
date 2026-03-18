import { z } from 'zod';
import { isoDateTime } from './primitives.js';

/**
 * Represents the selected account context for a Battery state snapshot.
 * Only one account is selected at any given time in the MVP contract.
 *
 * Note: `isSelected` is constrained to `true` as a contract invariant — the
 * core only emits the single active account. It is not a filterable property;
 * unselected accounts are never included in the state snapshot.
 */
export const accountSchema = z.object({
  id: z.string(),
  name: z.string(),
  planTier: z.string(),
  isSelected: z.literal(true),
});

/**
 * Active session usage within the current billing window.
 * Deferred parity fields (opus, sonnet, extraUsage) are tracked separately
 * and must remain absent in the MVP shape.
 *
 * `utilization` is a non-negative number. Values above 1.0 represent overrun.
 */
export const sessionSchema = z.object({
  utilization: z.number().min(0),
  resetsAt: isoDateTime.nullable(),
  isActive: z.boolean(),
});

export type Account = z.infer<typeof accountSchema>;
export type Session = z.infer<typeof sessionSchema>;
