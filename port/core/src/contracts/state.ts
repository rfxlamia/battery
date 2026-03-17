import { z } from 'zod';
import { accountSchema, sessionSchema } from './session.js';
import { weeklySchema, freshnessSchema } from './usage.js';
import { errorSchema } from './errors.js';

const isoDateTime = z.string().datetime({ offset: true });

export const batteryStateSchema = z.object({
  version: z.literal(1),
  status: z.enum(['ok', 'loading', 'login_required', 'error']),
  updatedAt: isoDateTime,
  account: accountSchema.optional(),
  session: sessionSchema.optional(),
  weekly: weeklySchema.optional(),
  freshness: freshnessSchema,
  error: errorSchema.optional(),
});

export type BatteryState = z.infer<typeof batteryStateSchema>;
