import { readFile, writeFile, mkdir, chmod, rename } from 'node:fs/promises';
import { join } from 'node:path';
import { randomBytes } from 'node:crypto';

export interface StoredTokens {
  accessToken: string;
  refreshToken?: string;
  expiresAt: string;
}

interface DiskStoredTokens {
  accessToken: string;
  refreshToken?: string;
  expiresAt: string | number;
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
  if (!isDiskStoredTokens(parsed)) return null;
  return normalizeStoredTokens(parsed);
}

function isDiskStoredTokens(v: unknown): v is DiskStoredTokens {
  if (typeof v !== 'object' || v === null) return false;
  const r = v as Record<string, unknown>;
  return (
    typeof r['accessToken'] === 'string' &&
    (typeof r['expiresAt'] === 'string' || typeof r['expiresAt'] === 'number') &&
    (r['refreshToken'] === undefined || typeof r['refreshToken'] === 'string')
  );
}

function normalizeStoredTokens(tokens: DiskStoredTokens): StoredTokens | null {
  const expiresAtValue = typeof tokens.expiresAt === 'number'
    ? tokens.expiresAt
    : new Date(tokens.expiresAt).getTime();
  if (Number.isNaN(expiresAtValue)) return null;
  return {
    accessToken: tokens.accessToken,
    ...(tokens.refreshToken ? { refreshToken: tokens.refreshToken } : {}),
    expiresAt: new Date(expiresAtValue).toISOString(),
  };
}

export async function writeTokens(
  homeDir: string,
  accountId: string,
  tokens: StoredTokens,
): Promise<void> {
  const tokensDir = join(homeDir, '.battery', 'tokens');
  await mkdir(tokensDir, { recursive: true, mode: 0o700 });
  await chmod(tokensDir, 0o700);
  const tokenPath = join(tokensDir, `${accountId}.json`);
  const tempPath = join(tokensDir, `.${accountId}.${randomBytes(4).toString('hex')}.tmp`);
  await writeFile(
    tempPath,
    JSON.stringify({
      accessToken: tokens.accessToken,
      ...(tokens.refreshToken ? { refreshToken: tokens.refreshToken } : {}),
      expiresAt: new Date(tokens.expiresAt).getTime(),
    }, null, 2),
    { mode: 0o600 },
  );
  await rename(tempPath, tokenPath);
  await chmod(tokenPath, 0o600);
}
