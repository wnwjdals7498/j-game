import { afterEach, beforeEach, expect, test } from 'vitest';
import type { DatabaseSync } from 'node:sqlite';
import { openDb } from '../src/db.js';
import { upsertUser } from '../src/repos/users.js';
import { listMoves } from '../src/repos/games.js';
import { GameError, MatchService } from '../src/play/match.js';
import { generateRoomCode } from '../src/play/roomCode.js';

let db: DatabaseSync;
let svc: MatchService;
let u1: number, u2: number, u3: number;
beforeEach(() => {
  db = openDb(':memory:');
  [u1, u2, u3] = ['1', '2', '3'].map(id => upsertUser(db, { provider: 'qa', providerUserId: id, displayName: id, isQa: true }).id) as [number, number, number];
  svc = new MatchService(db, { botDelayMs: 0 });
});
afterEach(() => db.close());
function room() {
  const game = svc.createRoom(u1, { gameId: 'omok', seat: 0 });
  svc.joinRoom(u2, game.roomCode!);
  return game;
}
function errorCode(fn: () => unknown, code: string) {
  try { fn(); expect.fail('expected GameError'); } catch (error) { expect(error).toBeInstanceOf(GameError); expect((error as GameError).code).toBe(code); }
}
test('room code uses 6 chars from the safe alphabet', () => {
  for (let i = 0; i < 200; i++) expect(generateRoomCode()).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/);
});
test('pvc: bot moves first when human takes white', async () => {
  const g = svc.createPvc(u1, { gameId: 'omok', seat: 1, botLevel: 'random', seed: 5 });
  await svc.whenIdle(); expect(svc.getView(g.id).moveCount).toBe(1);
});
test('pvc: human move is followed by a bot move', async () => {
  const g = svc.createPvc(u1, { gameId: 'omok', seat: 0, botLevel: 'random', seed: 5 });
  svc.playMove(g.id, u1, { x: 0, y: 0 }); await svc.whenIdle(); expect(svc.getView(g.id).moveCount).toBe(2);
});
test('pvc with same seed replays same bot moves', async () => {
  const a = svc.createPvc(u1, { gameId: 'omok', seat: 0, botLevel: 'random', seed: 5 });
  const b = svc.createPvc(u1, { gameId: 'omok', seat: 0, botLevel: 'random', seed: 5 });
  for (const g of [a, b]) { svc.playMove(g.id, u1, { x: 0, y: 0 }); await svc.whenIdle(); }
  expect(svc.getView(a.id).state).toEqual(svc.getView(b.id).state);
});
test('pvp: room create, join, alternate moves to a win', () => {
  const g = svc.createRoom(u1, { gameId: 'omok', seat: 0 }); expect(g.status).toBe('waiting');
  expect(svc.joinRoom(u2, g.roomCode!).status).toBe('playing');
  for (let x = 0; x < 4; x++) { svc.playMove(g.id, u1, { x, y: 0 }); svc.playMove(g.id, u2, { x, y: 1 }); }
  expect(svc.playMove(g.id, u1, { x: 4, y: 0 })).toMatchObject({ status: 'finished', outcome: { kind: 'win', winner: 0 }, endReason: 'rules' });
});
test('rejects second move in the same turn', () => {
  const g = room(); svc.playMove(g.id, u1, { x: 0, y: 0 });
  errorCode(() => svc.playMove(g.id, u1, { x: 1, y: 0 }), 'not_your_turn'); expect(listMoves(db, g.id)).toHaveLength(1);
});
test('creator joining own room gets same game', () => {
  const g = svc.createRoom(u1, { gameId: 'omok', seat: 0 }); expect(svc.joinRoom(u1, g.roomCode!)).toMatchObject({ id: g.id, status: 'waiting' });
});
test('third user cannot join a full room', () => { const g = room(); errorCode(() => svc.joinRoom(u3, g.roomCode!), 'room_full'); });
test('illegal and malformed moves are rejected', () => {
  const g = room(); svc.playMove(g.id, u1, { x: 0, y: 0 });
  for (const move of [{ x: 0, y: 0 }, { x: 'a' }, null]) errorCode(() => svc.playMove(g.id, u2, move), 'illegal_move');
});
test('non-player move is rejected', () => { const g = room(); errorCode(() => svc.playMove(g.id, u3, { x: 0, y: 0 }), 'not_player'); });
test('resign ends game with opponent win', () => {
  const g = room(); expect(svc.resign(g.id, u1)).toMatchObject({ status: 'finished', outcome: { kind: 'win', winner: 1 }, endReason: 'resign' });
  errorCode(() => svc.playMove(g.id, u2, { x: 0, y: 0 }), 'game_finished');
});
test('restores game from db after restart', () => {
  const g = room(); svc.playMove(g.id, u1, { x: 0, y: 0 }); svc.playMove(g.id, u2, { x: 0, y: 1 }); svc.playMove(g.id, u1, { x: 1, y: 0 });
  const restarted = new MatchService(db, { botDelayMs: 0 }); expect(restarted.getView(g.id).moveCount).toBe(3);
  expect(restarted.playMove(g.id, u2, { x: 1, y: 1 }).moveCount).toBe(4);
});
test('random seat assignment covers both seats', () => {
  const low = new MatchService(db, { botDelayMs: 0, rng: () => 0 });
  const high = new MatchService(db, { botDelayMs: 0, rng: () => 0.99 });
  expect(low.seatOf(low.createPvc(u1, { gameId: 'omok', seat: 'random', botLevel: 'random' }).id, u1)).toBe(0);
  const g = high.createPvc(u1, { gameId: 'omok', seat: 'random', botLevel: 'random' }); expect(high.seatOf(g.id, u1)).toBe(1);
  return high.whenIdle();
});
test('room code collisions retry and stop after ten attempts', () => {
  const fixed = new MatchService(db, { botDelayMs: 0, rng: () => 0 });
  fixed.createRoom(u1, { gameId: 'omok', seat: 0 });
  expect(() => fixed.createRoom(u2, { gameId: 'omok', seat: 0 })).toThrow('Could not generate a unique room code');
  const values = [...Array<number>(6).fill(0), ...Array<number>(6).fill(0.5)];
  const retry = new MatchService(db, { botDelayMs: 0, rng: () => values.shift()! });
  expect(retry.createRoom(u2, { gameId: 'omok', seat: 0 }).roomCode).not.toBe('AAAAAA');
});
test('restoring a bot turn schedules its move', async () => {
  const original = new MatchService(db, { botDelayMs: 10000 });
  const g = original.createPvc(u1, { gameId: 'omok', seat: 0, botLevel: 'random', seed: 5 });
  // Simulate a saved human move without leaving a timer in the original service.
  const { insertMove } = await import('../src/repos/games.js');
  insertMove(db, { gameId: g.id, seq: 0, player: 0, move: { x: 0, y: 0 }, createdAt: new Date().toISOString() });
  const restarted = new MatchService(db, { botDelayMs: 0 });
  restarted.getView(g.id); await restarted.whenIdle();
  expect(restarted.getView(g.id).moveCount).toBe(2);
});
test('a human move during a bot update still schedules the next bot move', async () => {
  const g = svc.createPvc(u1, { gameId: 'omok', seat: 1, botLevel: 'random', seed: 5 });
  let played = false;
  svc.on('update', (id: number) => {
    if (id === g.id && !played) {
      played = true;
      const state = svc.getView(id).state as { board: (number | null)[] };
      const index = state.board.findIndex(cell => cell === null);
      svc.playMove(id, u1, { x: index % 15, y: Math.floor(index / 15) });
    }
  });
  await svc.whenIdle(); expect(svc.getView(g.id).moveCount).toBe(3);
});
