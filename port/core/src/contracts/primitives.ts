import { z } from 'zod';

/**
 * ISO 8601 datetime string with mandatory timezone offset.
 * Shared primitive to ensure consistent datetime validation across all contract schemas.
 */
export const isoDateTime = z.string().datetime({ offset: true });
