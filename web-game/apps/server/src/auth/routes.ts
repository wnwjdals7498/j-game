import type { DatabaseSync } from 'node:sqlite';
import type { FastifyInstance } from 'fastify';
import type { ProviderInfo } from '@jgame/protocol';
import type { Config } from '../config.js';
import { createSession, deleteSession, upsertUser } from '../repos/users.js';
import { isRealLoginHost } from './hosts.js';
import { challenge, mapProfile, PendingAuthStore, randomToken, type OAuthProvider } from './oauth.js';
import { requireUser, SESSION_COOKIE, SESSION_TTL_SECONDS } from './session.js';

export function registerAuthRoutes(app: FastifyInstance, config: Config, db: DatabaseSync, fetcher: typeof fetch): void {
  const pending = new PendingAuthStore();
  function providerConfig(value: string): { provider: OAuthProvider; settings: NonNullable<Config['oauth'][OAuthProvider]> } | undefined {
    if (value !== 'kakao' && value !== 'naver' && value !== 'github') return undefined;
    const settings = config.oauth[value];
    return settings ? { provider: value, settings } : undefined;
  }

  app.get<{ Params: { provider: string } }>('/auth/:provider/start', async (request, reply) => {
    const selected = providerConfig(request.params.provider);
    if (!selected) return reply.code(404).send();
    const { provider, settings } = selected;
    const state = randomToken();
    const verifier = settings.pkce ? randomToken() : null;
    pending.put(state, { provider, verifier });
    const url = new URL(settings.authorizeUrl);
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('client_id', settings.clientId);
    url.searchParams.set('redirect_uri', `${config.publicOrigin}/auth/${provider}/callback`);
    url.searchParams.set('state', state);
    if (settings.scope) url.searchParams.set('scope', settings.scope);
    if (verifier) {
      url.searchParams.set('code_challenge_method', 'S256');
      url.searchParams.set('code_challenge', challenge(verifier));
    }
    return reply.redirect(url.toString());
  });

  app.get<{ Params: { provider: string }; Querystring: { code?: unknown; state?: unknown } }>('/auth/:provider/callback', async (request, reply) => {
    const selected = providerConfig(request.params.provider);
    const { code, state } = request.query;
    if (!selected || typeof state !== 'string' || !state || typeof code !== 'string' || !code) return reply.code(400).send({ code: 'bad_request' });
    const entry = pending.take(state, Date.now());
    if (!entry || entry.provider !== selected.provider) return reply.code(400).send({ code: 'bad_request' });
    const { provider, settings } = selected;
    const body = new URLSearchParams({ grant_type: 'authorization_code', code, redirect_uri: `${config.publicOrigin}/auth/${provider}/callback`, client_id: settings.clientId });
    if (settings.clientSecret) body.set('client_secret', settings.clientSecret);
    if (entry.verifier) body.set('code_verifier', entry.verifier);
    if (provider === 'naver') body.set('state', state);
    try {
      const tokenResponse = await fetcher(settings.tokenUrl, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' }, body: body.toString() });
      if (!tokenResponse.ok) return reply.code(400).send({ code: 'bad_request' });
      const token = await tokenResponse.json() as { access_token?: unknown } | null;
      if (typeof token?.access_token !== 'string' || !token.access_token) return reply.code(400).send({ code: 'bad_request' });
      const userResponse = await fetcher(settings.userUrl, { headers: { Authorization: `Bearer ${token.access_token}` } });
      if (!userResponse.ok) return reply.code(400).send({ code: 'bad_request' });
      const profile = mapProfile(provider, await userResponse.json());
      const user = upsertUser(db, { provider, ...profile, isQa: false });
      const sid = createSession(db, user.id, SESSION_TTL_SECONDS * 1000);
      reply.setCookie(SESSION_COOKIE, sid, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: SESSION_TTL_SECONDS });
      return reply.redirect('/#/games');
    } catch {
      return reply.code(400).send({ code: 'bad_request' });
    }
  });
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
