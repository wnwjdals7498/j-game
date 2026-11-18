import { afterEach, expect, test } from 'vitest';
import { openDb } from '../src/db.js';
import { createSession, getSessionUser, upsertUser } from '../src/repos/users.js';
import { insertGame, insertMove, listMoves } from '../src/repos/games.js';

const db = openDb(':memory:');
afterEach(() => { db.exec('DELETE FROM moves; DELETE FROM games; DELETE FROM sessions; DELETE FROM users'); });

test('upsertUser reuses the same provider user', () => {
  const first = upsertUser(db, { provider: 'qa', providerUserId: '1', displayName: 'old', isQa: true });
  const second = upsertUser(db, { provider: 'qa', providerUserId: '1', displayName: 'new', isQa: true });
  expect(second).toEqual({ ...first, name: 'new' });
});

test('expired session returns undefined', () => {
  const user = upsertUser(db, { provider: 'qa', providerUserId: '1', displayName: 'name', isQa: true });
  const now = new Date('2026-01-01T00:00:00.000Z');
  const sid = createSession(db, user.id, 1000, now);
  expect(getSessionUser(db, sid, new Date(now.getTime() + 2000))).toBeUndefined();
});

test('moves round-trip in seq order', () => {
  const game = insertGame(db, { gameId: 'omok', mode: 'pvc', roomCode: null, player0UserId: null, player1UserId: null, botLevel: 'basic', botSeed: 1, status: 'playing', endReason: null, resignedBy: null, createdAt: '2026-01-01T00:00:00.000Z', endedAt: null });
  for (const seq of [2, 0, 1]) insertMove(db, { gameId: game.id, seq, player: seq % 2, move: { x: seq, y: 0 }, createdAt: '2026-01-01T00:00:00.000Z' });
  expect(listMoves(db, game.id).map(({ seq, move }) => ({ seq, move }))).toEqual([0, 1, 2].map(seq => ({ seq, move: { x: seq, y: 0 } })));
});

test('game and session repositories support lookup and updates', async () => {
  const { getGame, updateGame, findGameByRoomCode, listUserGames } = await import('../src/repos/games.js');
  const { getUser, deleteSession } = await import('../src/repos/users.js');
  const user = upsertUser(db, { provider: 'qa', providerUserId: '2', displayName: 'player', isQa: true });
  const now = new Date('2026-01-01T00:00:00.000Z');
  const sid = createSession(db, user.id, 1000, now);
  expect(getUser(db, user.id)).toEqual(user);
  expect(getSessionUser(db, sid, now)).toEqual(user);
  expect(getSessionUser(db, sid, new Date(now.getTime() + 1000))).toBeUndefined();
  deleteSession(db, sid);
  expect(getSessionUser(db, sid, now)).toBeUndefined();
  const game = insertGame(db, { gameId: 'omok', mode: 'pvp', roomCode: 'ABC234', player0UserId: user.id, player1UserId: null, botLevel: null, botSeed: null, status: 'waiting', endReason: null, resignedBy: null, createdAt: now.toISOString(), endedAt: null });
  expect(findGameByRoomCode(db, 'ABC234')).toEqual(game);
  updateGame(db, { ...game, status: 'finished', endReason: 'resign', resignedBy: 0, endedAt: now.toISOString() });
  expect(getGame(db, game.id)).toMatchObject({ status: 'finished', endReason: 'resign', resignedBy: 0 });
  expect(listUserGames(db, user.id)).toEqual([getGame(db, game.id)]);
});
