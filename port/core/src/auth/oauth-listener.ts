import { createServer, IncomingMessage, ServerResponse } from 'node:http';

export interface OAuthListener {
  port: number;
  codePromise: Promise<string>;
  stop: () => Promise<void>;
}

interface StartOAuthListenerOptions {
  path: string;
  expectedState?: string;
  timeoutMs?: number;
}

export async function startOAuthListener(
  opts: StartOAuthListenerOptions,
): Promise<OAuthListener> {
  const { path, expectedState, timeoutMs = 5 * 60 * 1_000 } = opts;

  let resolveCode!: (code: string) => void;
  let rejectCode!: (err: Error) => void;
  const codePromise = new Promise<string>((resolve, reject) => {
    resolveCode = resolve;
    rejectCode = reject;
  });

  const server = createServer((req: IncomingMessage, res: ServerResponse) => {
    const url = new URL(req.url ?? '/', `http://127.0.0.1`);
    if (url.pathname === path) {
      const code = url.searchParams.get('code');
      const returnedState = url.searchParams.get('state');

      if (code) {
        if (expectedState && returnedState !== expectedState) {
          res.writeHead(400, { Connection: 'close' });
          res.end('Invalid state parameter');
          return;
        }

        const body =
          '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Battery</title></head>' +
          '<body style="font-family:system-ui,-apple-system,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0">' +
          '<div style="text-align:center"><h2>Authenticated!</h2>' +
          '<p>You can close this tab and return to Battery.</p></div></body></html>';
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8',
          'Content-Length': Buffer.byteLength(body),
          Connection: 'close',
        });
        res.end(body);
        // Close server immediately after receiving the code so the process does
        // not keep the port open during the token-exchange round-trip.
        server.close();
        resolveCode(code);
        return;
      }
    }
    res.writeHead(200, { Connection: 'close' });
    res.end('Waiting for auth...');
  });

  await new Promise<void>((resolve, reject) => {
    server.listen(0, '127.0.0.1', () => resolve());
    server.once('error', reject);
  });

  const addr = server.address();
  if (!addr || typeof addr === 'string') {
    throw new Error('Could not bind OAuth callback server');
  }
  const port = addr.port;

  const timeout = setTimeout(() => {
    rejectCode(new Error('OAuth login timed out'));
    server.close();
  }, timeoutMs);

  codePromise.then(() => clearTimeout(timeout), () => clearTimeout(timeout));

  const stop = (): Promise<void> =>
    new Promise((resolve) => {
      clearTimeout(timeout);
      // Reject any caller still awaiting codePromise so they don't hang.
      rejectCode(new Error('OAuth listener stopped'));
      // Server may already be closed if code was received; close() on an
      // already-closed server fires the callback immediately.
      server.close(() => resolve());
    });

  return { port, codePromise, stop };
}
