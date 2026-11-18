import { randomUUID } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { defineConfig } from '@playwright/test';

const dbDir = join(tmpdir(), `web-game-e2e-${randomUUID()}`);
process.env.WEB_GAME_E2E_DIR = dbDir;

export default defineConfig({
  testDir: '.',
  globalTeardown: './teardown.ts',
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
