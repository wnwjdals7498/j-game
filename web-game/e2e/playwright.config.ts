import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { defineConfig } from '@playwright/test';

const dbDir = mkdtempSync(join(tmpdir(), 'web-game-e2e-'));

export default defineConfig({
  testDir: '.',
  timeout: 120_000,
  use: { baseURL: 'http://127.0.0.1:8851' },
  webServer: {
    command: 'npm run build && node apps/server/dist/main.js',
    cwd: join(import.meta.dirname, '..'),
    url: 'http://127.0.0.1:8851/api/auth/providers',
    reuseExistingServer: false,
    timeout: 120_000,
    env: { QA_LOGIN: '1', PORT: '8851', DB_PATH: join(dbDir, 'web-game.sqlite'), BOT_DELAY_MS: '0' },
  },
});
