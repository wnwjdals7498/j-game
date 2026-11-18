import { afterEach, expect, test, vi } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { openDb } from '../src/db.js';
import { mapProfile, PendingAuthStore } from '../src/auth/oauth.js';
import { testConfig } from './helpers.js';

const apps: FastifyInstance[] = [];
afterEach(async () => { await Promise.all(apps.splice(0).map((app) => app.close())); });
const oauth = loadConfig({ GITHUB_CLIENT_ID: 'h', KAKAO_CLIENT_ID: 'k', NAVER_CLIENT_ID: 'n', NAVER_CLIENT_SECRET: 'secret' }).oauth;
async function makeApp(fetcher: typeof fetch = vi.fn(), providers = oauth) {
  const app = await buildApp(testConfig({ oauth: providers }), { fetch: fetcher });
  apps.push(app);
  return app;
}
async function start(app: FastifyInstance, provider = 'github') {
  const response = await app.inject(`/auth/${provider}/start`);
  return new URL(response.headers.location as string);
}
function callback(app: FastifyInstance, provider: string, code: string, state: string | null) {
  return app.inject({ url: `/auth/${provider}/callback?code=${code}&state=${state}`, headers: { cookie: `oauth_state=${state}` } });
}
function fakeFetch(profile: unknown = { id: 7, login: 'octo', name: 'Octo' }) {
  return vi.fn<typeof fetch>().mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'token' }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify(profile), { status: 200 }));
}

test('start redirects with client_id, redirect_uri, state and PKCE', async () => {
  const app = await makeApp();
  const response = await app.inject('/auth/github/start');
  expect(response.statusCode).toBe(302);
  const url = new URL(response.headers.location as string);
  expect(response.cookies.find((cookie) => cookie.name === 'oauth_state')).toMatchObject({ value: url.searchParams.get('state'), httpOnly: true, sameSite: 'Lax', path: '/auth', maxAge: 600 });
  expect(url.hostname).toBe('github.com');
  expect(url.searchParams.get('client_id')).toBe('h');
  expect(url.searchParams.get('redirect_uri')).toBe('http://localhost:8840/auth/github/callback');
  expect(url.searchParams.get('state')!.length).toBeGreaterThanOrEqual(32);
  expect(url.searchParams.get('code_challenge_method')).toBe('S256');
  expect(url.searchParams.get('code_challenge')).toHaveLength(43);
});
test('kakao start has no PKCE parameters', async () => {
  const url = await start(await makeApp(), 'kakao');
  expect(url.searchParams.has('code_challenge')).toBe(false);
});
test('unknown or disabled provider start returns 404', async () => {
  const app = await makeApp(vi.fn(), { github: oauth.github });
  expect((await app.inject('/auth/naver/start')).statusCode).toBe(404);
  expect((await app.inject('/auth/unknown/start')).statusCode).toBe(404);
});
test('callback with unknown state is rejected without fetch', async () => {
  const fetcher = vi.fn<typeof fetch>();
  const app = await makeApp(fetcher);
  const response = await app.inject('/auth/github/callback?code=x&state=unknown');
  expect(response.statusCode).toBe(400);
  expect(response.json()).toEqual({ code: 'bad_request' });
  expect(fetcher).not.toHaveBeenCalled();
});
test('callback creates user and session', async () => {
  const fetcher = fakeFetch();
  const app = await makeApp(fetcher);
  const url = await start(app);
  const state = url.searchParams.get('state');
  const response = await callback(app, 'github', 'abc', state);
  expect(response.statusCode).toBe(302);
  expect(response.headers.location).toBe('/#/games');
  expect(response.cookies.some((cookie) => cookie.name === 'sid')).toBe(true);
  expect(response.cookies.find((cookie) => cookie.name === 'oauth_state')?.value).toBe('');
  const body = new URLSearchParams(fetcher.mock.calls[0][1]?.body as string);
  expect(body.get('code_verifier')).toHaveLength(43);
  expect(body.get('code')).toBe('abc');
  expect(body.get('redirect_uri')).toBe('http://localhost:8840/auth/github/callback');
  expect(fetcher.mock.calls[1][1]?.headers).toMatchObject({ Authorization: 'Bearer token' });
  const sid = response.cookies.find((cookie) => cookie.name === 'sid')!;
  const me = await app.inject({ url: '/api/me', headers: { cookie: `sid=${sid.value}` } });
  expect(me.json().user).toMatchObject({ provider: 'github', name: 'Octo' });
});
test('state cannot be replayed or used for another provider', async () => {
  const fetcher = fakeFetch();
  const app = await makeApp(fetcher);
  const state = (await start(app)).searchParams.get('state');
  expect((await callback(app, 'github', 'x', state)).statusCode).toBe(302);
  expect((await callback(app, 'github', 'x', state)).statusCode).toBe(400);
  const otherState = (await start(app)).searchParams.get('state');
  expect((await callback(app, 'kakao', 'x', otherState)).statusCode).toBe(400);
});
test('mapProfile reads each provider fields and empty name fallback', () => {
  expect(mapProfile('kakao', { id: 1, kakao_account: { profile: { nickname: '카' } } })).toEqual({ providerUserId: '1', displayName: '카' });
  expect(mapProfile('naver', { response: { id: 'n1', nickname: '네' } })).toEqual({ providerUserId: 'n1', displayName: '네' });
  expect(mapProfile('github', { id: 7, login: 'octo', name: null })).toEqual({ providerUserId: '7', displayName: 'octo' });
  expect(mapProfile('github', { id: 7, login: '', name: '' }).displayName).toBe('github 사용자');
});
test('token endpoint error returns 400 without session', async () => {
  const fetcher = vi.fn<typeof fetch>().mockResolvedValue(new Response('', { status: 401 }));
  const app = await makeApp(fetcher);
  const state = (await start(app)).searchParams.get('state');
  const response = await callback(app, 'github', 'x', state);
  expect(response.statusCode).toBe(400);
  expect(response.cookies.some((cookie) => cookie.name === 'sid')).toBe(false);
  expect(response.cookies.find((cookie) => cookie.name === 'oauth_state')?.value).toBe('');
});
test('missing token and failed user response do not create a session', async () => {
  for (const responses of [[new Response('{}')], [new Response('{"access_token":"x"}'), new Response('', { status: 500 })]]) {
    const fetcher = vi.fn<typeof fetch>();
    for (const response of responses) fetcher.mockResolvedValueOnce(response);
    const app = await makeApp(fetcher);
    const state = (await start(app)).searchParams.get('state');
    const result = await callback(app, 'github', 'x', state);
    expect(result.statusCode).toBe(400);
    expect(result.cookies.some((cookie) => cookie.name === 'sid')).toBe(false);
  }
});
test('naver token request includes state and secret', async () => {
  const fetcher = fakeFetch({ response: { id: 'n1', nickname: '네' } });
  const app = await makeApp(fetcher);
  const state = (await start(app, 'naver')).searchParams.get('state');
  expect((await callback(app, 'naver', 'x', state)).statusCode).toBe(302);
  const body = new URLSearchParams(fetcher.mock.calls[0][1]?.body as string);
  expect(body.get('state')).toBe(state);
  expect(body.get('client_secret')).toBe('secret');
});
test('pending states expire at ten minutes and are single use', () => {
  vi.useFakeTimers();
  try {
    vi.setSystemTime(1000);
    const store = new PendingAuthStore();
    store.put('one', { provider: 'github', verifier: null });
    expect(store.take('one', 1000 + 599999)).toEqual({ provider: 'github', verifier: null });
    expect(store.take('one', 1000)).toBeUndefined();
    store.put('two', { provider: 'kakao', verifier: null });
    expect(store.take('two', 1000 + 600000)).toBeUndefined();
  } finally { vi.useRealTimers(); }
});

test('valid state requires matching browser cookie', async () => {
  const fetcher = vi.fn<typeof fetch>();
  const app = await makeApp(fetcher);
  for (const cookie of [undefined, 'oauth_state=wrong']) {
    const state = (await start(app)).searchParams.get('state');
    const response = await app.inject({ url: `/auth/github/callback?code=x&state=${state}`, headers: cookie ? { cookie } : {} });
    expect(response.statusCode).toBe(400);
    expect(response.cookies.some((item) => item.name === 'sid')).toBe(false);
    expect(response.cookies.find((item) => item.name === 'oauth_state')?.value).toBe('');
  }
  expect(fetcher).not.toHaveBeenCalled();
});
test('pending store removes expired entries on put and limits size', () => {
  vi.useFakeTimers();
  try {
    vi.setSystemTime(1000);
    const store = new PendingAuthStore();
    store.put('expired', { provider: 'github', verifier: null });
    vi.setSystemTime(601000);
    store.put('fresh', { provider: 'github', verifier: null });
    expect(store.size).toBe(1);
    for (let i = 0; i < 1001; i++) store.put(`state${i}`, { provider: 'github', verifier: null });
    expect(store.size).toBe(1000);
    expect(store.take('state0', Date.now())).toBeUndefined();
    expect(store.take('state1000', Date.now())).toEqual({ provider: 'github', verifier: null });
  } finally { vi.useRealTimers(); }
});
test('database failure returns 500', async () => {
  const db = openDb(':memory:');
  const app = await buildApp(testConfig({ oauth }), { db, fetch: fakeFetch() });
  apps.push(app);
  const state = (await start(app)).searchParams.get('state');
  db.close();
  const response = await callback(app, 'github', 'x', state);
  expect(response.statusCode).toBe(500);
  expect(response.cookies.some((cookie) => cookie.name === 'sid')).toBe(false);
  expect(response.cookies.find((cookie) => cookie.name === 'oauth_state')?.value).toBe('');
});
