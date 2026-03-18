import { describe, expect, it } from 'vitest';
import { parseStateJson } from '../lib/state-reader.js';

describe('parseStateJson', () => {
  it('returns a valid state for a well-formed ok contract', () => {
    const raw = JSON.stringify({
      version: 1,
      status: 'ok',
      updatedAt: '2026-03-17T00:00:00.000Z',
      account: { id: 'a1', name: 'Alice', planTier: 'pro', isSelected: true },
      session: { utilization: 0.42, resetsAt: '2026-03-17T01:18:00.000Z', isActive: true },
      weekly: { utilization: 0.31, resetsAt: '2026-03-21T00:00:00.000Z' },
      freshness: { staleAfterSeconds: 300 },
    });
    const result = parseStateJson(raw);
    expect(result).toMatchObject({ status: 'ok', version: 1 });
  });

  it('returns null for missing file (null input)', () => {
    expect(parseStateJson(null)).toBeNull();
  });

  it('returns null for malformed JSON', () => {
    expect(parseStateJson('not valid json {')).toBeNull();
  });

  it('returns null for JSON missing required fields', () => {
    expect(parseStateJson(JSON.stringify({ foo: 'bar' }))).toBeNull();
  });

  it('returns null for wrong version', () => {
    expect(
      parseStateJson(
        JSON.stringify({
          version: 2,
          status: 'ok',
          freshness: { staleAfterSeconds: 300 },
        }),
      ),
    ).toBeNull();
  });

  it('returns state for login_required (no session or account required)', () => {
    const raw = JSON.stringify({
      version: 1,
      status: 'login_required',
      freshness: { staleAfterSeconds: 300 },
    });
    const result = parseStateJson(raw);
    expect(result).toMatchObject({ status: 'login_required' });
  });

  it('returns state for loading status', () => {
    const raw = JSON.stringify({
      version: 1,
      status: 'loading',
      freshness: { staleAfterSeconds: 300 },
    });
    expect(parseStateJson(raw)).toMatchObject({ status: 'loading' });
  });

  it('returns state for error status with error field present', () => {
    const raw = JSON.stringify({
      version: 1,
      status: 'error',
      freshness: { staleAfterSeconds: 300 },
      error: { code: 'rate_limited', message: 'Too many requests' },
    });
    expect(parseStateJson(raw)).toMatchObject({ status: 'error' });
  });

  it('returns null for error status without error field', () => {
    const raw = JSON.stringify({
      version: 1,
      status: 'error',
      freshness: { staleAfterSeconds: 300 },
    });
    expect(parseStateJson(raw)).toBeNull();
  });
});
