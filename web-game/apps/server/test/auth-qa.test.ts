import { afterEach, expect, test } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { qaLogin, testConfig } from './helpers.js';

const apps: FastifyInstance[] = [];
afterEach(async () => { await Promise.all(apps.splice(0).map((app) => app.close())); });
async function makeApp(over: Parameters<typeof testConfig>[0] = {}) {
  const app = await buildApp(testConfig(over));
  apps.push(app);
  return app;
}

test('qa login disabled returns 404', async () => {
  const app = await makeApp({ qaLogin: false });
  const r = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name: 'tester1' } });
  expect(r.statusCode).toBe(404);
});
test('qa login sets session and /api/me returns user', async () => {
  const app = await makeApp();
  const r = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name: 'tester1' } });
  expect(r.statusCode).toBe(200);
  expect(r.headers['set-cookie']).toMatch(/sid=.+HttpOnly.*SameSite=Lax/);
  expect(r.headers['set-cookie']).toContain('Max-Age=604800');
  expect(r.headers['set-cookie']).toContain('Path=/');
  const me = await app.inject({ method: 'GET', url: '/api/me', headers: { cookie: r.headers['set-cookie'] as string } });
  expect(me.statusCode).toBe(200);
  expect(me.json().user).toMatchObject({ name: 'tester1', isQa: true, provider: 'qa' });
});
test('qa name is trimmed and must be 1-20 chars', async () => {
  const app = await makeApp();
  const valid = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name: '  a  ' } });
  expect(valid.json().user.name).toBe('a');
  for (const name of ['', '   ', 'a'.repeat(21)]) {
    const r = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name } });
    expect(r.statusCode).toBe(400);
    expect(r.json()).toEqual({ code: 'bad_request' });
  }
  const unicode = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name: '😀'.repeat(20) } });
  expect(unicode.statusCode).toBe(200);
});
test('same qa name reuses the account', async () => {
  const app = await makeApp();
  const first = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name: 'tester1' } });
  const second = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name: 'tester1' } });
  expect(first.json().user.id).toBe(second.json().user.id);
});
test('logout invalidates the session', async () => {
  const app = await makeApp();
  const cookie = await qaLogin(app, 'tester1');
  const logout = await app.inject({ method: 'POST', url: '/api/auth/logout', headers: { cookie } });
  expect(logout.statusCode).toBe(204);
  const me = await app.inject({ method: 'GET', url: '/api/me', headers: { cookie } });
  expect(me.statusCode).toBe(401);
  expect(me.json()).toEqual({ code: 'unauthorized' });
});
test('real providers listed only on localhost host', async () => {
  const app = await makeApp({ google: { clientId: 'google', jwksUrl: 'https://example.com/jwks', issuers: [] }, oauth: { github: { clientId: 'github', authorizeUrl: 'url', tokenUrl: 'url', userUrl: 'url', pkce: true } } });
  for (const [host, ids] of [['localhost:8840', ['google', 'github', 'qa']], ['10.8.0.1:8840', ['qa']], ['127.0.0.1:8840', ['qa']], ['localhost.example:8840', ['qa']]] as const) {
    const r = await app.inject({ method: 'GET', url: '/api/auth/providers', headers: { host } });
    expect(r.json().providers.map((provider: { id: string }) => provider.id)).toEqual(ids);
    if (host === 'localhost:8840') expect(r.json().providers).toEqual([{ id: 'google', kind: 'gis', clientId: 'google' }, { id: 'github', kind: 'redirect', startUrl: '/auth/github/start' }, { id: 'qa', kind: 'qa' }]);
  }
});
