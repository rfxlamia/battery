import { z } from 'zod';
import { isoDateTime } from './primitives.js';

/**
 * Rolling weekly usage window.
 * Deferred parity fields (opus, sonnet, extraUsage) are tracked separately
 * and must remain absent in the MVP shape.
 *
 * `utilization` is a non-negative number. Values above 1.0 represent overrun.
 */
export const weeklySchema = z.object({
  utilization: z.number().min(0),
  resetsAt: isoDateTime.nullable(),
});

/**
 * Metadata about how fresh the cached state is.
 * The GNOME extension must treat state older than this window as stale.
 */
export const freshnessSchema = z.object({
  staleAfterSeconds: z.number().int().positive(),
});

export type Weekly = z.infer<typeof weeklySchema>;
export type Freshness = z.infer<typeof freshnessSchema>;
