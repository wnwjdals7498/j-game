import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test } from 'vitest';
import { openDb } from '../src/db.js';

test('openDb creates missing parent directories', () => {
  const dir = mkdtempSync(join(tmpdir(), 'jgame-db-'));
  try {
    const db = openDb(join(dir, 'nested', 'data', 'game.sqlite'));
    expect(db.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'").get()).toMatchObject({ name: 'users' });
    db.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
