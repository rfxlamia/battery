import { z } from 'zod';

/**
 * Typed error payload surfaced when status === 'error'.
 */
export const errorSchema = z.object({
  kind: z.enum(['unauthorized', 'rate_limited', 'server_error', 'network_error', 'decoding_error']),
  message: z.string(),
  retryAfterSeconds: z.number().int().positive().optional(),
});

export type BatteryError = z.infer<typeof errorSchema>;
