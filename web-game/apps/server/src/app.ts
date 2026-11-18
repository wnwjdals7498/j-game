import type { DatabaseSync } from 'node:sqlite';
import Fastify, { type FastifyInstance } from 'fastify';
import cookie from '@fastify/cookie';
import type { Config } from './config.js';
import { openDb } from './db.js';
import { getSessionUser } from './repos/users.js';
import { registerAuthRoutes } from './auth/routes.js';
import { SESSION_COOKIE } from './auth/session.js';

export async function buildApp(config: Config, deps: { db?: DatabaseSync; fetch?: typeof fetch } = {}): Promise<FastifyInstance> {
  const app = Fastify();
  const db = deps.db ?? openDb(config.dbPath);
  await app.register(cookie);
  app.decorateRequest('user', null);
  app.addHook('onRequest', async (request) => {
    const sid = request.cookies[SESSION_COOKIE];
    request.user = sid ? getSessionUser(db, sid, new Date()) ?? null : null;
  });
  if (!deps.db) app.addHook('onClose', async () => { db.close(); });
  registerAuthRoutes(app, config, db);
  return app;
}
