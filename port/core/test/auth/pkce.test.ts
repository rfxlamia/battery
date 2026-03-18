import { describe, expect, it } from 'vitest';
import { createPkcePair } from '../../src/auth/pkce.js';

describe('createPkcePair', () => {
  it('returns a verifier and challenge in URL-safe format', () => {
    const pair = createPkcePair();
    expect(pair.verifier).toMatch(/^[A-Za-z0-9\-_]+$/);
    expect(pair.challenge).toMatch(/^[A-Za-z0-9\-_]+$/);
    expect(pair.verifier.length).toBeGreaterThanOrEqual(43);
  });
});
