import { afterEach, beforeEach, expect, test } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { qaLogin, testConfig } from './helpers.js';

let app: FastifyInstance;
let u1: string, u2: string, u3: string;
beforeEach(async () => { app = await buildApp(testConfig()); u1 = await qaLogin(app, 'one'); u2 = await qaLogin(app, 'two'); u3 = await qaLogin(app, 'three'); });
afterEach(async () => { await app.close(); });
const post = (url: string, cookie: string, payload: unknown) => app.inject({ method: 'POST', url, headers: { cookie }, payload });
async function room() { const g = (await post('/api/rooms', u1, { gameId: 'omok', seat: 0 })).json().game; await post('/api/rooms/join', u2, { roomCode: g.roomCode.toLowerCase() }); return g; }
test('unauthenticated api returns 401', async () => { expect((await app.inject('/api/me/games')).statusCode).toBe(401); });
test('pvc create returns 201 with game view', async () => { const r = await post('/api/games/pvc', u1, { gameId: 'omok', seat: 0, botLevel: 'random' }); expect(r.statusCode).toBe(201); expect(r.json().game.players[1].kind).toBe('bot'); });
test('join with lowercase code works', async () => { const g = await room(); expect((await app.inject({ url: `/api/games/${g.id}`, headers: { cookie: u2 } })).json().game.status).toBe('playing'); });
test('history lists result from each user view', async () => { const g = await room(); const { WebSocket } = await import('ws'); await app.listen({ port: 0 }); const address = app.server.address(); if (!address || typeof address === 'string') throw Error('address'); const ws = new WebSocket(`ws://127.0.0.1:${address.port}/ws`, { headers: { cookie: u2 } }); await new Promise<void>(resolve => ws.once('open', resolve)); ws.send(JSON.stringify({ type: 'subscribe', gameId: g.id })); await new Promise<void>(resolve => ws.once('message', () => resolve())); ws.send(JSON.stringify({ type: 'resign', gameId: g.id })); await new Promise<void>(resolve => ws.once('message', () => resolve())); ws.close(); const a = (await app.inject({ url: '/api/me/games', headers: { cookie: u1 } })).json().games[0]; const b = (await app.inject({ url: '/api/me/games', headers: { cookie: u2 } })).json().games[0]; expect(a).toMatchObject({ result: 'win', opponentName: 'two' }); expect(b).toMatchObject({ result: 'loss', opponentName: 'one' }); });
test('error codes map to http status', async () => { const g = await room(); expect((await app.inject({ url: '/api/games/999', headers: { cookie: u1 } })).statusCode).toBe(404); expect((await app.inject({ url: `/api/games/${g.id}`, headers: { cookie: u3 } })).statusCode).toBe(403); });
