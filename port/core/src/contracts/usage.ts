import { z } from 'zod';
import { isoDateTime } from './primitives.js';

/**
 * Rolling weekly usage window.
 *
 * `utilization` is a normalized fraction (0.0–1.0). The API returns percent scale (0–100);
 * the TypeScript core must divide by 100 before writing to this field.
 * Values above 1.0 represent overrun.
 *
 * Deferred parity fields — intentionally absent from MVP contract:
 * - `sonnetUtilization`, `opusUtilization`: per-model 7-day utilization (API fields seven_day_sonnet, seven_day_opus)
 * - `extraUsage`: extra credits usage object (API field extra_usage)
 * - `burnRate` / `projectedLimitTime` / `projectedAtReset`: OLS regression projection from BurnRateCalculator.swift
 * - `usageLevel` / color thresholds: ColorThresholds.swift UsageLevel enum (low/medium/high/critical)
 * - `todayPeakSeen`, `activeDays`, `dailyPeaks`: heatmap / sparkline display data from UsageViewModel.swift
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
