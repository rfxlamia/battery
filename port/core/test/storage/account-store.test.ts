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

  it('returns null when accounts.json does not exist', async () => {
    const account = await readSelectedAccount(tmpDir);
    expect(account).toBeNull();
  });
});
