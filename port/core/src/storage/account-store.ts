import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

interface StoredAccount {
  id: string;
  name: string;
  planTier: string;
  selected: boolean;
}

export interface SelectedAccount {
  id: string;
  name: string;
  planTier: string;
}

export async function readSelectedAccount(homeDir: string): Promise<SelectedAccount | null> {
  const accountsPath = join(homeDir, '.battery', 'accounts.json');
  let raw: string;
  try {
    raw = await readFile(accountsPath, 'utf8');
  } catch {
    return null;
  }

  let accounts: unknown;
  try {
    accounts = JSON.parse(raw);
  } catch {
    return null;
  }

  if (!Array.isArray(accounts)) return null;

  const selected = (accounts as StoredAccount[]).find((a) => a.selected === true);
  if (!selected) return null;

  return { id: selected.id, name: selected.name, planTier: selected.planTier };
}
