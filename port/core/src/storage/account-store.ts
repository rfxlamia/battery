import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

interface StoredAccount {
  id: string;
  name: string;
  planTier: string;
  selected: boolean;
}

function isStoredAccount(v: unknown): v is StoredAccount {
  if (typeof v !== 'object' || v === null) return false;
  const r = v as Record<string, unknown>;
  return (
    typeof r['id'] === 'string' &&
    typeof r['name'] === 'string' &&
    typeof r['planTier'] === 'string' &&
    typeof r['selected'] === 'boolean'
  );
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

  const selected = (accounts as unknown[]).find(isStoredAccount);
  if (!selected || !selected.selected) return null;

  return { id: selected.id, name: selected.name, planTier: selected.planTier };
}
