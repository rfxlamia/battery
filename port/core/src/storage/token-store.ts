import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';

export interface StoredTokens {
  accessToken: string;
  refreshToken?: string;
  expiresAt: string;
}

export async function readTokens(homeDir: string, accountId: string): Promise<StoredTokens | null> {
  const tokenPath = join(homeDir, '.battery', 'tokens', `${accountId}.json`);
  let raw: string;
  try {
    raw = await readFile(tokenPath, 'utf8');
  } catch {
    return null;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!isStoredTokens(parsed)) return null;
  return parsed;
}

function isStoredTokens(v: unknown): v is StoredTokens {
  if (typeof v !== 'object' || v === null) return false;
  const r = v as Record<string, unknown>;
  return (
    typeof r['accessToken'] === 'string' &&
    typeof r['expiresAt'] === 'string' &&
    (r['refreshToken'] === undefined || typeof r['refreshToken'] === 'string')
  );
}

export async function writeTokens(
  homeDir: string,
  accountId: string,
  tokens: StoredTokens,
): Promise<void> {
  const tokensDir = join(homeDir, '.battery', 'tokens');
  await mkdir(tokensDir, { recursive: true, mode: 0o700 });
  const tokenPath = join(tokensDir, `${accountId}.json`);
  await writeFile(tokenPath, JSON.stringify(tokens, null, 2), { mode: 0o600 });
}
