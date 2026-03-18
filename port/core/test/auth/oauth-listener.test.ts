import { describe, expect, it } from 'vitest';
import { startOAuthListener } from '../../src/auth/oauth-listener.js';

describe('startOAuthListener', () => {
  it('accepts /callback?code=... and resolves the code once', async () => {
    const listener = await startOAuthListener({ path: '/callback', timeoutMs: 2_000 });
    const res = await fetch(`http://127.0.0.1:${listener.port}/callback?code=abc123`);
    expect(await res.text()).toContain('Battery');
    await expect(listener.codePromise).resolves.toBe('abc123');
    await listener.stop();
  });

  it('rejects after timeout', async () => {
    const listener = await startOAuthListener({ path: '/callback', timeoutMs: 50 });
    await expect(listener.codePromise).rejects.toThrow(/timed out/i);
  });

  it('rejects callback with mismatched state', async () => {
    const listener = await startOAuthListener({
      path: '/callback',
      expectedState: 'correct-state',
      timeoutMs: 2_000,
    });
    const res = await fetch(
      `http://127.0.0.1:${listener.port}/callback?code=abc&state=wrong-state`,
    );
    expect(res.status).toBe(400);
    await listener.stop();
  });

  it('accepts callback with matching state', async () => {
    const listener = await startOAuthListener({
      path: '/callback',
      expectedState: 'my-state',
      timeoutMs: 2_000,
    });
    const res = await fetch(
      `http://127.0.0.1:${listener.port}/callback?code=abc&state=my-state`,
    );
    expect(res.status).toBe(200);
    await expect(listener.codePromise).resolves.toBe('abc');
    await listener.stop();
  });
});
