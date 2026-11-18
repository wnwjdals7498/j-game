import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  resolve: { alias: {
    '@jgame/engine': fileURLToPath(new URL('../../packages/engine/src/index.ts', import.meta.url)),
    '@jgame/protocol': fileURLToPath(new URL('../../packages/protocol/src/index.ts', import.meta.url)),
  } },
  server: { proxy: { '/api': 'http://localhost:8840', '/auth': 'http://localhost:8840', '/ws': { target: 'ws://localhost:8840', ws: true } } },
  test: { name: 'web', environment: 'jsdom' },
});
