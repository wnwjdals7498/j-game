import type { DatabaseSync } from 'node:sqlite';
import type { FastifyInstance } from 'fastify';
import type { ProviderInfo } from '@jgame/protocol';
import type { Config } from '../config.js';
import { createSession, deleteSession, upsertUser } from '../repos/users.js';
import { isRealLoginHost } from './hosts.js';
import { requireUser, SESSION_COOKIE, SESSION_TTL_SECONDS } from './session.js';

export function registerAuthRoutes(app: FastifyInstance, config: Config, db: DatabaseSync): void {
  app.get('/api/auth/providers', async (request) => {
    const providers: ProviderInfo[] = [];
    if (isRealLoginHost(request.headers.host)) {
      if (config.google) providers.push({ id: 'google', kind: 'gis', clientId: config.google.clientId });
      for (const id of ['kakao', 'naver', 'github'] as const) {
        if (config.oauth[id]) providers.push({ id, kind: 'redirect', startUrl: `/auth/${id}/start` });
      }
    }
    if (config.qaLogin) providers.push({ id: 'qa', kind: 'qa' });
    return { providers };
  });

  if (config.qaLogin) app.post('/api/auth/qa', async (request, reply) => {
    const body = request.body as { name?: unknown } | null;
    const name = typeof body?.name === 'string' ? body.name.trim() : '';
    if (Array.from(name).length < 1 || Array.from(name).length > 20) return reply.code(400).send({ code: 'bad_request' });
    const user = upsertUser(db, { provider: 'qa', providerUserId: name, displayName: name, isQa: true });
    const sid = createSession(db, user.id, SESSION_TTL_SECONDS * 1000);
    reply.setCookie(SESSION_COOKIE, sid, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: SESSION_TTL_SECONDS });
    return { user };
  });

  app.post('/api/auth/logout', async (request, reply) => {
    const sid = request.cookies[SESSION_COOKIE];
    if (sid) deleteSession(db, sid);
    reply.clearCookie(SESSION_COOKIE, { path: '/' });
    return reply.code(204).send();
  });
  app.get('/api/me', async (request, reply) => {
    const user = requireUser(request, reply);
    if (!user) return reply;
    return { user };
  });
}
