import { z } from 'zod';
import { isoDateTime } from './primitives.js';
import { accountSchema, sessionSchema } from './session.js';
import { weeklySchema, freshnessSchema } from './usage.js';
import { errorSchema } from './errors.js';

export const batteryStateSchema = z.object({
  version: z.literal(1),
  status: z.enum(['ok', 'loading', 'login_required', 'error']),
  updatedAt: isoDateTime,
  account: accountSchema.optional(),
  session: sessionSchema.optional(),
  weekly: weeklySchema.optional(),
  freshness: freshnessSchema,
  error: errorSchema.optional(),
}).refine(
  (data) => data.status !== 'error' || data.error !== undefined,
  { message: "error field is required when status is 'error'" },
);

export type BatteryState = z.infer<typeof batteryStateSchema>;
