import { afterEach, beforeEach, expect, test } from 'vitest';
import { WebSocket } from 'ws';
import { omok } from '@jgame/engine';
import type { GameView, ServerMessage } from '@jgame/protocol';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { qaLogin, testConfig } from './helpers.js';

let app: FastifyInstance, url: string, u1: string, u2: string, u3: string;
const sockets: WebSocket[] = [];
const queues = new WeakMap<WebSocket, ServerMessage[]>();
function connect(cookie?: string, origin?: string): Promise<WebSocket> { return new Promise((resolve, reject) => { const ws = new WebSocket(url, { headers: { ...(cookie ? { Cookie: cookie } : {}), ...(origin ? { Origin: origin } : {}) } }); sockets.push(ws); queues.set(ws, []); ws.on('message', data => queues.get(ws)!.push(JSON.parse(data.toString()) as ServerMessage)); ws.once('open', () => resolve(ws)); ws.once('error', reject); }); }
async function next(ws: WebSocket, predicate: (m: ServerMessage) => boolean): Promise<ServerMessage> { const end = Date.now() + 5000; while (Date.now() < end) { const q = queues.get(ws)!; const i = q.findIndex(predicate); if (i >= 0) return q.splice(i, 1)[0]!; await new Promise(resolve => setTimeout(resolve, 5)); } throw Error('message timeout'); }
async function nextState(ws: WebSocket, predicate: (g: GameView) => boolean): Promise<GameView> { const m = await next(ws, m => m.type === 'state' && predicate(m.game)); if (m.type !== 'state') throw Error('state'); return m.game; }
function send(ws: WebSocket, value: unknown) { ws.send(JSON.stringify(value)); }
async function create(mode: 'pvp' | 'pvc' = 'pvp') { const r = await app.inject({ method: 'POST', url: mode === 'pvp' ? '/api/rooms' : '/api/games/pvc', headers: { cookie: u1 }, payload: { gameId: 'omok', seat: 0, ...(mode === 'pvc' ? { botLevel: 'random', seed: 5 } : {}) } }); const game = r.json().game as GameView; if (mode === 'pvp') await app.inject({ method: 'POST', url: '/api/rooms/join', headers: { cookie: u2 }, payload: { roomCode: game.roomCode } }); return game; }
beforeEach(async () => { app = await buildApp(testConfig()); u1 = await qaLogin(app, 'one'); u2 = await qaLogin(app, 'two'); u3 = await qaLogin(app, 'three'); await app.listen({ port: 0, host: '127.0.0.1' }); const a = app.server.address(); if (!a || typeof a === 'string') throw Error('address'); url = `ws://127.0.0.1:${a.port}/ws`; });
afterEach(async () => { for (const ws of sockets.splice(0)) ws.terminate(); await app.close(); });
test('ws without session is closed with unauthorized', async () => { const ws = await connect(); expect(await next(ws, m => m.type === 'error')).toMatchObject({ code: 'unauthorized' }); if (ws.readyState !== WebSocket.CLOSED) await new Promise<void>(resolve => ws.once('close', () => resolve())); expect(ws.readyState).toBe(WebSocket.CLOSED); });
test('foreign origin is unauthorized', async () => { const ws = await connect(u1, 'http://evil.example'); expect(await next(ws, m => m.type === 'error')).toMatchObject({ code: 'unauthorized' }); if (ws.readyState !== WebSocket.CLOSED) await new Promise<void>(resolve => ws.once('close', () => resolve())); expect(ws.readyState).toBe(WebSocket.CLOSED); });
test('pvp game played to the end over ws', async () => { const g = await create(); const a = await connect(u1), b = await connect(u2); send(a, { type: 'subscribe', gameId: g.id }); send(b, { type: 'subscribe', gameId: g.id }); await nextState(a, s => s.online.every(Boolean)); await nextState(b, s => s.online.every(Boolean)); for (let n = 0; n < 9; n++) { send(n % 2 ? b : a, { type: 'move', gameId: g.id, move: { x: Math.floor(n / 2), y: n % 2 } }); const state = await nextState(a, s => s.moveCount === n + 1); await nextState(b, s => s.moveCount === n + 1); if (n === 8) expect(state).toMatchObject({ status: 'finished', outcome: { kind: 'win', winner: 0 } }); } });
test('pvc game finishes over ws', async () => { const g = await create('pvc'); const a = await connect(u1); send(a, { type: 'subscribe', gameId: g.id }); let state = await nextState(a, s => s.moveCount === 0); while (state.status !== 'finished') { const move = omok.legalMoves(state.state as Parameters<typeof omok.legalMoves>[0])[0]; send(a, { type: 'move', gameId: g.id, move }); state = await nextState(a, s => s.moveCount > state.moveCount && (s.status === 'finished' || s.moveCount % 2 === 0)); } expect(state.status).toBe('finished'); });
test('reconnect resumes current state', async () => { const g = await create(); const a = await connect(u1), b = await connect(u2); send(a, { type: 'subscribe', gameId: g.id }); send(b, { type: 'subscribe', gameId: g.id }); await nextState(b, s => s.online.every(Boolean)); send(a, { type: 'move', gameId: g.id, move: { x: 0, y: 0 } }); await nextState(b, s => s.moveCount === 1); send(b, { type: 'move', gameId: g.id, move: { x: 1, y: 0 } }); await nextState(b, s => s.moveCount === 2); a.close(); await nextState(b, s => !s.online[0] && s.online[1]); const c = await connect(u1); send(c, { type: 'subscribe', gameId: g.id }); expect((await nextState(c, s => s.online.every(Boolean))).moveCount).toBe(2); });
test('malformed message keeps connection', async () => { const g = await create(); const a = await connect(u1); a.send('not json'); expect(await next(a, m => m.type === 'error')).toMatchObject({ code: 'bad_request' }); send(a, { type: 'subscribe', gameId: g.id }); await nextState(a, () => true); });
test('non-player cannot subscribe', async () => { const g = await create(); const a = await connect(u3); send(a, { type: 'subscribe', gameId: g.id }); expect(await next(a, m => m.type === 'error')).toMatchObject({ code: 'not_player' }); });
test('move error is sent only to the sender', async () => { const g = await create(); const a = await connect(u1), b = await connect(u2); send(a, { type: 'subscribe', gameId: g.id }); send(b, { type: 'subscribe', gameId: g.id }); await nextState(a, s => s.online.every(Boolean)); send(b, { type: 'move', gameId: g.id, move: { x: 0, y: 0 } }); expect(await next(b, m => m.type === 'error')).toMatchObject({ code: 'not_your_turn' }); await new Promise(resolve => setTimeout(resolve, 50)); expect(queues.get(a)!.some(m => m.type === 'error')).toBe(false); });

test('a participant may move without subscribing', async () => { const g = await create(); const a = await connect(u1), b = await connect(u2); send(b, { type: 'subscribe', gameId: g.id }); await nextState(b, () => true); send(a, { type: 'move', gameId: g.id, move: { x: 0, y: 0 } }); expect((await nextState(b, s => s.moveCount === 1)).online).toEqual([false, true]); });
test('one socket tracks several games and multiple sockets per seat', async () => { const g = await create(), h = await create(); const a = await connect(u1), a2 = await connect(u1), b = await connect(u2); for (const id of [g.id, h.id]) { send(a, { type: 'subscribe', gameId: id }); send(a2, { type: 'subscribe', gameId: id }); send(b, { type: 'subscribe', gameId: id }); await nextState(b, s => s.id === id && s.online.every(Boolean)); } a.close(); for (const id of [g.id, h.id]) expect((await nextState(b, s => s.id === id && s.online.every(Boolean))).online).toEqual([true, true]); a2.close(); for (const id of [g.id, h.id]) await nextState(b, s => s.id === id && !s.online[0] && s.online[1]); });
test('closing app cancels pending bot timers', async () => { const delayed = await buildApp(testConfig({ botDelayMs: 10000 })); const cookie = await qaLogin(delayed, 'timer'); await delayed.inject({ method: 'POST', url: '/api/games/pvc', headers: { cookie }, payload: { gameId: 'omok', seat: 1, botLevel: 'random' } }); await delayed.close(); });

test('HTTP game views reflect subscribed sockets', async () => {
  const created = await app.inject({ method: 'POST', url: '/api/rooms', headers: { cookie: u1 }, payload: { gameId: 'omok', seat: 0 } });
  const g = created.json().game as GameView;
  const a = await connect(u1);
  send(a, { type: 'subscribe', gameId: g.id });
  await nextState(a, s => s.online[0]);
  const joined = await app.inject({ method: 'POST', url: '/api/rooms/join', headers: { cookie: u2 }, payload: { roomCode: g.roomCode } });
  expect(joined.json().game.online).toEqual([true, false]);
  const b = await connect(u2);
  send(b, { type: 'subscribe', gameId: g.id });
  await nextState(b, s => s.online.every(Boolean));
  const get = () => app.inject({ url: `/api/games/${g.id}`, headers: { cookie: u1 } });
  expect((await get()).json().game.online).toEqual([true, true]);
  a.close();
  await nextState(b, s => !s.online[0] && s.online[1]);
  expect((await get()).json().game.online).toEqual([false, true]);
});

test('logout invalidates an existing socket before a move', async () => {
  const g = await create(); const a = await connect(u1), b = await connect(u2);
  send(a, { type: 'subscribe', gameId: g.id }); send(b, { type: 'subscribe', gameId: g.id });
  await nextState(b, s => s.online.every(Boolean));
  expect((await app.inject({ method: 'POST', url: '/api/auth/logout', headers: { cookie: u1 } })).statusCode).toBe(204);
  send(a, { type: 'move', gameId: g.id, move: { x: 0, y: 0 } });
  expect(await next(a, m => m.type === 'error')).toMatchObject({ code: 'unauthorized' });
  if (a.readyState !== WebSocket.CLOSED) await new Promise<void>(resolve => a.once('close', () => resolve()));
  expect((await nextState(b, s => !s.online[0])).moveCount).toBe(0);
  expect((await app.inject({ url: `/api/games/${g.id}`, headers: { cookie: u2 } })).json().game.moveCount).toBe(0);
});
test('unknown message type keeps connection usable', async () => {
  const g = await create(); const a = await connect(u1);
  send(a, { type: 'nope' }); expect(await next(a, m => m.type === 'error')).toMatchObject({ code: 'bad_request' });
  send(a, { type: 'subscribe', gameId: g.id }); await nextState(a, () => true);
});
test('non-player cannot move or change the move history', async () => {
  const g = await create(); const a = await connect(u3);
  send(a, { type: 'move', gameId: g.id, move: { x: 0, y: 0 } });
  expect(await next(a, m => m.type === 'error')).toMatchObject({ code: 'not_player' });
  expect((await app.inject({ url: `/api/games/${g.id}`, headers: { cookie: u1 } })).json().game.moveCount).toBe(0);
});
