import { z } from 'zod';

const isoDateTime = z.string().datetime({ offset: true });

/**
 * Represents the selected account context for a Battery state snapshot.
 * Only one account is selected at any given time in the MVP contract.
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
 */
export const sessionSchema = z.object({
  utilization: z.number(),
  resetsAt: isoDateTime.nullable(),
  isActive: z.boolean(),
});

export type Account = z.infer<typeof accountSchema>;
export type Session = z.infer<typeof sessionSchema>;
