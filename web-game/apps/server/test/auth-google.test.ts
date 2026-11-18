import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';
import { afterAll, afterEach, beforeAll, expect, test } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { testConfig } from './helpers.js';

const apps: FastifyInstance[] = [];
let server: Server;
let jwksUrl: string;
let privateKey: Awaited<ReturnType<typeof generateKeyPair>>['privateKey'];
let requests = 0;
beforeAll(async () => {
  const keys = await generateKeyPair('RS256');
  privateKey = keys.privateKey;
  const publicKey = await exportJWK(keys.publicKey);
  server = createServer((_request, response) => {
    requests++;
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ keys: [{ ...publicKey, kid: 'test', alg: 'RS256', use: 'sig' }] }));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  jwksUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}/jwks`;
});
afterEach(async () => { await Promise.all(apps.splice(0).map((app) => app.close())); });
afterAll(async () => { await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve())); });
async function makeApp(configured = true) {
  const google = configured ? { clientId: 'g-client', jwksUrl, issuers: ['https://accounts.google.com', 'accounts.google.com'] } : null;
  const app = await buildApp(testConfig({ google }));
  apps.push(app);
  return app;
}
async function token(over: { iss?: string; aud?: string; exp?: number; sub?: string; name?: string; email?: string } = {}) {
  const { iss = 'https://accounts.google.com', aud = 'g-client', exp = Math.floor(Date.now() / 1000) + 300, sub = '123', ...claims } = over;
  return new SignJWT({ name: '구글', ...claims }).setProtectedHeader({ alg: 'RS256', kid: 'test' }).setIssuer(iss).setAudience(aud).setSubject(sub).setExpirationTime(exp).sign(privateKey);
}
function login(app: FastifyInstance, credential: string) {
  return app.inject({ method: 'POST', url: '/api/auth/google', payload: { credential } });
}

test('valid credential logs in and reuses the JWKS cache', async () => {
  const app = await makeApp();
  const credential = await token();
  const count = requests;
  const response = await login(app, credential);
  expect(response.statusCode).toBe(200);
  expect(response.json().user).toMatchObject({ provider: 'google', name: '구글', isQa: false });
  const sid = response.cookies.find((cookie) => cookie.name === 'sid');
  expect(sid).toMatchObject({ httpOnly: true, sameSite: 'Lax', path: '/', maxAge: 604800 });
  const me = await app.inject({ url: '/api/me', headers: { cookie: `sid=${sid!.value}` } });
  expect(me.json().user).toEqual(response.json().user);
  expect((await login(app, credential)).json().user.id).toBe(response.json().user.id);
  expect(requests - count).toBe(1);
});
test('issuer without https is accepted', async () => {
  expect((await login(await makeApp(), await token({ iss: 'accounts.google.com' }))).statusCode).toBe(200);
});
test('wrong audience is rejected', async () => {
  const response = await login(await makeApp(), await token({ aud: 'other' }));
  expect(response.statusCode).toBe(401);
  expect(response.json()).toEqual({ code: 'unauthorized' });
  expect(response.cookies).toHaveLength(0);
});
test('expired credential is rejected', async () => {
  expect((await login(await makeApp(), await token({ exp: Math.floor(Date.now() / 1000) - 60 }))).statusCode).toBe(401);
});
test('wrong issuer and malformed token are rejected', async () => {
  const app = await makeApp();
  for (const credential of [await token({ iss: 'https://other.example' }), 'bad-token']) {
    const response = await login(app, credential);
    expect(response.statusCode).toBe(401);
    expect(response.json()).toEqual({ code: 'unauthorized' });
  }
});
test('invalid signature and missing required claims are rejected', async () => {
  const app = await makeApp();
  const otherKey = (await generateKeyPair('RS256')).privateKey;
  const signed = (key: typeof privateKey) => new SignJWT({}).setProtectedHeader({ alg: 'RS256', kid: 'test' }).setIssuer('https://accounts.google.com').setAudience('g-client').setSubject('123').setExpirationTime('5m').sign(key);
  const missingSubject = await new SignJWT({}).setProtectedHeader({ alg: 'RS256', kid: 'test' }).setIssuer('https://accounts.google.com').setAudience('g-client').setExpirationTime('5m').sign(privateKey);
  const missingExpiry = await new SignJWT({}).setProtectedHeader({ alg: 'RS256', kid: 'test' }).setIssuer('https://accounts.google.com').setAudience('g-client').setSubject('123').sign(privateKey);
  for (const credential of [await signed(otherKey), missingSubject, missingExpiry]) {
    const response = await login(app, credential);
    expect(response.statusCode).toBe(401);
    expect(response.json()).toEqual({ code: 'unauthorized' });
    expect(response.cookies).toHaveLength(0);
  }
});
test('name falls back to email and default', async () => {
  const app = await makeApp();
  expect((await login(app, await token({ name: undefined, email: 'a@example.com' }))).json().user.name).toBe('a@example.com');
  expect((await login(app, await token({ name: undefined }))).json().user.name).toBe('Google 사용자');
});
test('missing or non-string credential and non-JSON content are rejected', async () => {
  const app = await makeApp();
  for (const payload of [{}, { credential: 1 }, null]) {
    const response = await app.inject({ method: 'POST', url: '/api/auth/google', payload });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({ code: 'bad_request' });
  }
  for (const contentType of ['text/plain', 'application/x-www-form-urlencoded']) {
    const response = await app.inject({ method: 'POST', url: '/api/auth/google', headers: { 'content-type': contentType }, payload: JSON.stringify({ credential: await token() }) });
    expect(response.statusCode).toBe(400);
    expect(response.json()).toEqual({ code: 'bad_request' });
  }
});
test('google not configured returns 404', async () => {
  expect((await login(await makeApp(false), 'token')).statusCode).toBe(404);
});
