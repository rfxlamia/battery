import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

interface PortableStoredAccount {
  id: string;
  name: string;
  planTier: string;
  selected: boolean;
}

interface SwiftStoredAccount {
  id: string;
  name: string;
  planTier: string;
  isDefault?: boolean;
}

function isPortableStoredAccount(v: unknown): v is PortableStoredAccount {
  if (typeof v !== 'object' || v === null) return false;
  const r = v as Record<string, unknown>;
  return (
    typeof r['id'] === 'string' &&
    typeof r['name'] === 'string' &&
    typeof r['planTier'] === 'string' &&
    typeof r['selected'] === 'boolean'
  );
}

function isSwiftStoredAccount(v: unknown): v is SwiftStoredAccount {
  if (typeof v !== 'object' || v === null) return false;
  const r = v as Record<string, unknown>;
  return (
    typeof r['id'] === 'string' &&
    typeof r['name'] === 'string' &&
    typeof r['planTier'] === 'string' &&
    (r['isDefault'] === undefined || typeof r['isDefault'] === 'boolean')
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

  const entries = accounts as unknown[];

  if (entries.some(isPortableStoredAccount)) {
    const selected = entries.find(
      (candidate): candidate is PortableStoredAccount =>
        isPortableStoredAccount(candidate) && candidate.selected,
    );
    if (!selected) return null;
    return { id: selected.id, name: selected.name, planTier: selected.planTier };
  }

  const swiftAccounts = entries.filter(isSwiftStoredAccount);
  if (swiftAccounts.length === 0) return null;

  const selected = swiftAccounts.find((candidate) => candidate.isDefault === true) ?? swiftAccounts[0];
  if (!selected) return null;

  return { id: selected.id, name: selected.name, planTier: selected.planTier };
}
