import { rmSync } from 'node:fs';

export default function teardown(): void { rmSync(process.env.WEB_GAME_E2E_DIR!, { recursive: true, force: true }); }
