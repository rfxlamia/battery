import { describe, expect, it, beforeEach } from 'vitest';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readSelectedAccount } from '../../src/storage/account-store.js';

describe('readSelectedAccount', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'battery-test-'));
    await mkdir(join(tmpDir, '.battery'));
  });

  it('returns the account marked as selected', async () => {
    await writeFile(
      join(tmpDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', selected: true },
        { id: 'acct-2', name: 'Bob', planTier: 'free', selected: false },
      ]),
    );
    const account = await readSelectedAccount(tmpDir);
    expect(account).toMatchObject({ id: 'acct-1' });
  });

  it('returns null when no account is selected', async () => {
    await writeFile(
      join(tmpDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', selected: false },
      ]),
    );
    const account = await readSelectedAccount(tmpDir);
    expect(account).toBeNull();
  });

  it('returns the selected account even when it is not first in the file', async () => {
    await writeFile(
      join(tmpDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', selected: false },
        { id: 'acct-2', name: 'Bob', planTier: 'free', selected: true },
      ]),
    );
    const account = await readSelectedAccount(tmpDir);
    expect(account).toMatchObject({ id: 'acct-2' });
  });

  it('returns null when accounts.json does not exist', async () => {
    const account = await readSelectedAccount(tmpDir);
    expect(account).toBeNull();
  });

  it('falls back to the Swift account format using isDefault', async () => {
    await writeFile(
      join(tmpDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro', isDefault: false },
        { id: 'acct-2', name: 'Bob', planTier: 'max_5x', isDefault: true },
      ]),
    );
    const account = await readSelectedAccount(tmpDir);
    expect(account).toMatchObject({ id: 'acct-2', planTier: 'max_5x' });
  });

  it('falls back to the first Swift account when none is marked default', async () => {
    await writeFile(
      join(tmpDir, '.battery', 'accounts.json'),
      JSON.stringify([
        { id: 'acct-1', name: 'Alice', planTier: 'pro' },
        { id: 'acct-2', name: 'Bob', planTier: 'max' },
      ]),
    );
    const account = await readSelectedAccount(tmpDir);
    expect(account).toMatchObject({ id: 'acct-1' });
  });
});
