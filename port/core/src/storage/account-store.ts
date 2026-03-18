import { readFile, writeFile, mkdir } from 'node:fs/promises';
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
    r['selected'] === undefined &&
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
  const selectedAccountId = await readPersistedSelectedAccountId(homeDir);
  const portableAccounts = entries.filter(isPortableStoredAccount);
  const swiftAccounts = entries.filter(isSwiftStoredAccount);

  if (selectedAccountId) {
    const selectedPortable = portableAccounts.find((candidate) => candidate.id === selectedAccountId);
    if (selectedPortable) {
      return { id: selectedPortable.id, name: selectedPortable.name, planTier: selectedPortable.planTier };
    }

    const selectedSwift = swiftAccounts.find((candidate) => candidate.id === selectedAccountId);
    if (selectedSwift) {
      return { id: selectedSwift.id, name: selectedSwift.name, planTier: selectedSwift.planTier };
    }
  }

  if (portableAccounts.length > 0) {
    const selectedPortable = portableAccounts.find((candidate) => candidate.selected);
    if (selectedPortable) {
      return { id: selectedPortable.id, name: selectedPortable.name, planTier: selectedPortable.planTier };
    }
  }

  if (swiftAccounts.length === 0) return null;

  const selected =
    swiftAccounts.find((candidate) => candidate.isDefault === true) ??
    swiftAccounts[0];
  if (!selected) return null;

  return { id: selected.id, name: selected.name, planTier: selected.planTier };
}

export async function readPersistedSelectedAccountId(homeDir: string): Promise<string | null> {
  const selectedAccountPath = join(homeDir, '.battery', 'selected-account-id');
  let raw: string;
  try {
    raw = await readFile(selectedAccountPath, 'utf8');
  } catch {
    return null;
  }

  const trimmed = raw.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export interface StoredAccountRecord {
  id: string;
  name: string;
  email: null;
  planTier: string;
  isDefault: boolean;
  createdAt: string;
}

export async function readAllAccounts(homeDir: string): Promise<StoredAccountRecord[]> {
  const accountsPath = join(homeDir, '.battery', 'accounts.json');
  let raw: string;
  try {
    raw = await readFile(accountsPath, 'utf8');
  } catch {
    return [];
  }
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as StoredAccountRecord[]) : [];
  } catch {
    return [];
  }
}

export async function writeAccounts(homeDir: string, accounts: StoredAccountRecord[]): Promise<void> {
  const batteryDir = join(homeDir, '.battery');
  await mkdir(batteryDir, { recursive: true });
  await writeFile(join(batteryDir, 'accounts.json'), JSON.stringify(accounts, null, 2), 'utf8');
}

export async function writeSelectedAccountId(homeDir: string, accountId: string): Promise<void> {
  const batteryDir = join(homeDir, '.battery');
  await mkdir(batteryDir, { recursive: true });
  await writeFile(join(batteryDir, 'selected-account-id'), accountId, 'utf8');
}
