import { describe, expect, it } from 'vitest';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
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
  it('calls the OAuth usage endpoint with the Swift parity headers', async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    const fetchSpy = async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init });
      return new Response(JSON.stringify(sample200), { status: 200 });
    };

    await fetchUsage(fetchSpy as typeof fetch, 'valid-token');

    expect(calls).toHaveLength(1);
    expect(calls[0]?.url).toBe('https://api.anthropic.com/api/oauth/usage');
    expect(calls[0]?.init?.headers).toMatchObject({
      Authorization: 'Bearer valid-token',
      'anthropic-beta': 'oauth-2025-04-20',
      'User-Agent': 'Battery/0.2.4',
    });
  });

  it('returns raw usage data on 200 (normalisation is build-state responsibility)', async () => {
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

  it('omits retryAfterSeconds when Retry-After is not numeric', async () => {
    const fetchMockInvalid429 = async () =>
      new Response(JSON.stringify({ error: { type: 'rate_limit_error' } }), {
        status: 429,
        headers: { 'Retry-After': 'tomorrow' },
      });

    await expect(fetchUsage(fetchMockInvalid429 as typeof fetch, 'token')).rejects.toMatchObject({
      kind: 'rate_limited',
    });
    await expect(fetchUsage(fetchMockInvalid429 as typeof fetch, 'token')).rejects.not.toHaveProperty(
      'retryAfterSeconds',
    );
  });

  it('still surfaces rate_limited when local rate-limit logging fails', async () => {
    const homeDirFile = await mkdtemp(join(tmpdir(), 'battery-home-file-'));
    const fakeHome = join(homeDirFile, 'not-a-directory');
    await writeFile(fakeHome, 'occupied');

    const previousHome = process.env['HOME'];
    process.env['HOME'] = fakeHome;
    try {
      await expect(fetchUsage(fetchMock429, 'token')).rejects.toMatchObject({
        kind: 'rate_limited',
        retryAfterSeconds: 60,
      });
    } finally {
      if (previousHome === undefined) delete process.env['HOME'];
      else process.env['HOME'] = previousHome;
    }
  });

  it('throws server_error on 500', async () => {
    await expect(fetchUsage(fetchMock500, 'token')).rejects.toMatchObject({
      kind: 'server_error',
    });
  });
});
