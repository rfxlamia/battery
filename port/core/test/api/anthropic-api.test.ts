import { describe, expect, it } from 'vitest';
import { fetchUsage } from '../../src/api/anthropic-api.js';

const sample200 = {
  five_hour: { utilization: 42.5, resets_at: '2026-03-17T13:00:00Z' },
  seven_day: { utilization: 61.2, resets_at: '2026-03-23T00:00:00Z' },
  seven_day_sonnet: { utilization: 38.1, resets_at: '2026-03-23T00:00:00Z' },
  seven_day_opus: { utilization: 12.4, resets_at: '2026-03-23T00:00:00Z' },
  extra_usage: { is_enabled: false, used_credits: 0, monthly_limit: 50, utilization: 0 },
};

const fetchMock200 = async () => new Response(JSON.stringify(sample200), { status: 200 });

const fetchMock401 = async () =>
  new Response(JSON.stringify({ error: { type: 'authentication_error' } }), { status: 401 });

const fetchMock429 = async () =>
  new Response(JSON.stringify({ error: { type: 'rate_limit_error' } }), {
    status: 429,
    headers: { 'Retry-After': '60' },
  });

const fetchMock500 = async () => new Response('Internal Server Error', { status: 500 });

describe('fetchUsage', () => {
  it('returns normalized usage data on 200', async () => {
    const result = await fetchUsage(fetchMock200, 'valid-token');
    expect(result).toMatchObject({
      fiveHour: expect.objectContaining({ utilization: 42.5 }) as unknown,
      sevenDay: expect.objectContaining({ utilization: 61.2 }) as unknown,
    });
  });

  it('throws unauthorized on 401', async () => {
    await expect(fetchUsage(fetchMock401, 'bad-token')).rejects.toMatchObject({
      kind: 'unauthorized',
    });
  });

  it('throws rate_limited on 429 with retryAfterSeconds', async () => {
    await expect(fetchUsage(fetchMock429, 'token')).rejects.toMatchObject({
      kind: 'rate_limited',
      retryAfterSeconds: 60,
    });
  });

  it('throws server_error on 500', async () => {
    await expect(fetchUsage(fetchMock500, 'token')).rejects.toMatchObject({
      kind: 'server_error',
    });
  });
});
