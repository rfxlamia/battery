import { z } from 'zod';

const isoDateTime = z.string().datetime({ offset: true });

export const batteryStateSchema = z.object({
  version: z.literal(1),
  status: z.enum(['ok', 'loading', 'login_required', 'error']),
  updatedAt: isoDateTime,
  account: z.object({
    id: z.string(),
    name: z.string(),
    planTier: z.string(),
    isSelected: z.literal(true),
  }).optional(),
  session: z.object({
    utilization: z.number(),
    resetsAt: isoDateTime.nullable(),
    isActive: z.boolean(),
  }).optional(),
  weekly: z.object({
    utilization: z.number(),
    resetsAt: isoDateTime.nullable(),
  }).optional(),
  freshness: z.object({
    staleAfterSeconds: z.number().int().positive(),
  }),
  error: z.object({
    kind: z.enum(['unauthorized', 'rate_limited', 'server_error', 'network_error', 'decoding_error']),
    message: z.string(),
    retryAfterSeconds: z.number().int().positive().optional(),
  }).optional(),
});

export type BatteryState = z.infer<typeof batteryStateSchema>;
