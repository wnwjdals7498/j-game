import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  resolve: { alias: {
    '@jgame/engine': fileURLToPath(new URL('./packages/engine/src/index.ts', import.meta.url)),
    '@jgame/protocol': fileURLToPath(new URL('./packages/protocol/src/index.ts', import.meta.url)),
  } },
  test: { projects: ['packages/*', 'apps/*'] },
});
