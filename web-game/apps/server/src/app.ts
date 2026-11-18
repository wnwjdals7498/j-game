import type { DatabaseSync } from 'node:sqlite';
import Fastify, { type FastifyInstance } from 'fastify';
import cookie from '@fastify/cookie';
import websocket from '@fastify/websocket';
import { MatchService } from './play/match.js';
import { registerPlayRoutes } from './play/routes.js';
import { GamePresence, registerPlayWebSocket } from './play/ws.js';
import type { Config } from './config.js';
import { openDb } from './db.js';
import { getSessionUser } from './repos/users.js';
import { registerAuthRoutes } from './auth/routes.js';
import { SESSION_COOKIE } from './auth/session.js';

export async function buildApp(config: Config, deps: { db?: DatabaseSync; fetch?: typeof fetch } = {}): Promise<FastifyInstance> {
  const app = Fastify();
  const db = deps.db ?? openDb(config.dbPath);
  await app.register(cookie);
  await app.register(websocket);
  const matches = new MatchService(db, { botDelayMs: config.botDelayMs });
  const presence = new GamePresence();
  app.addHook('onClose', async () => { matches.close(); });
  app.decorateRequest('user', null);
  app.addHook('onRequest', async (request) => {
    const sid = request.cookies[SESSION_COOKIE];
    request.user = sid ? getSessionUser(db, sid, new Date()) ?? null : null;
  });
  if (!deps.db) app.addHook('onClose', async () => { db.close(); });
  registerAuthRoutes(app, config, db, deps.fetch ?? fetch);
  registerPlayRoutes(app, db, matches, presence);
  registerPlayWebSocket(app, matches, presence);
  return app;
}
