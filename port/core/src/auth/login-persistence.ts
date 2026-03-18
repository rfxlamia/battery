import { randomUUID } from 'node:crypto';
import {
  readAllAccounts,
  writeAccounts,
  writeSelectedAccountId,
  readPersistedSelectedAccountId,
  StoredAccountRecord,
} from '../storage/account-store.js';
import { writeTokens } from '../storage/token-store.js';
import type { TokenResult } from './oauth-login.js';

export interface PersistLoginResult {
  accountId: string;
}

export async function persistLoginResult(
  homeDir: string,
  tokens: TokenResult,
): Promise<PersistLoginResult> {
  const existing = await readAllAccounts(homeDir);
  const selectedId = await readPersistedSelectedAccountId(homeDir);

  let accountId: string;
  let accounts: StoredAccountRecord[];

  if (existing.length > 0 && selectedId) {
    // Re-auth: replace tokens for the currently selected account
    const found = existing.find((a) => a.id === selectedId);
    if (found) {
      accountId = found.id;
      accounts = existing;
    } else {
      // Selected ID doesn't match any account — create a new one
      const newAccount = makeAccount(`Account ${existing.length + 1}`, false);
      accountId = newAccount.id;
      accounts = [...existing, newAccount];
    }
  } else if (existing.length > 0 && !selectedId) {
    // Accounts exist but nothing is selected — create Account N+1
    const newAccount = makeAccount(`Account ${existing.length + 1}`, false);
    accountId = newAccount.id;
    accounts = [...existing, newAccount];
  } else {
    // First login
    const newAccount = makeAccount('Account 1', true);
    accountId = newAccount.id;
    accounts = [newAccount];
  }

  const expiresAt = new Date(Date.now() + tokens.expiresIn * 1_000).toISOString();

  await writeTokens(homeDir, accountId, {
    accessToken: tokens.accessToken,
    ...(tokens.refreshToken ? { refreshToken: tokens.refreshToken } : {}),
    expiresAt,
  });
  await writeAccounts(homeDir, accounts);
  await writeSelectedAccountId(homeDir, accountId);

  return { accountId };
}

function makeAccount(name: string, isDefault: boolean): StoredAccountRecord {
  return {
    id: randomUUID(),
    name,
    email: null,
    planTier: 'unknown',
    isDefault,
    createdAt: new Date().toISOString(),
  };
}
