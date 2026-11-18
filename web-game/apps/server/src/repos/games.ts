import type { DatabaseSync } from 'node:sqlite';

export interface GameRow {
  id: number; gameId: string; mode: 'pvp' | 'pvc'; roomCode: string | null;
  player0UserId: number | null; player1UserId: number | null; botLevel: string | null; botSeed: number | null;
  status: 'waiting' | 'playing' | 'finished'; endReason: 'rules' | 'resign' | null; resignedBy: number | null;
  createdAt: string; endedAt: string | null;
}
export interface MoveRow { gameId: number; seq: number; player: number; move: unknown; createdAt: string }
const columns = 'id, game_id AS gameId, mode, room_code AS roomCode, player0_user_id AS player0UserId, player1_user_id AS player1UserId, bot_level AS botLevel, bot_seed AS botSeed, status, end_reason AS endReason, resigned_by AS resignedBy, created_at AS createdAt, ended_at AS endedAt';

export function insertGame(db: DatabaseSync, game: Omit<GameRow, 'id'>): GameRow {
  return db.prepare(`INSERT INTO games (game_id, mode, room_code, player0_user_id, player1_user_id, bot_level, bot_seed, status, end_reason, resigned_by, created_at, ended_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING ${columns}`).get(game.gameId, game.mode, game.roomCode, game.player0UserId, game.player1UserId, game.botLevel, game.botSeed, game.status, game.endReason, game.resignedBy, game.createdAt, game.endedAt) as unknown as GameRow;
}
export function getGame(db: DatabaseSync, id: number): GameRow | undefined {
  return db.prepare(`SELECT ${columns} FROM games WHERE id = ?`).get(id) as unknown as GameRow | undefined;
}
export function updateGame(db: DatabaseSync, game: GameRow): void {
  db.prepare('UPDATE games SET game_id = ?, mode = ?, room_code = ?, player0_user_id = ?, player1_user_id = ?, bot_level = ?, bot_seed = ?, status = ?, end_reason = ?, resigned_by = ?, created_at = ?, ended_at = ? WHERE id = ?').run(game.gameId, game.mode, game.roomCode, game.player0UserId, game.player1UserId, game.botLevel, game.botSeed, game.status, game.endReason, game.resignedBy, game.createdAt, game.endedAt, game.id);
}
export function findGameByRoomCode(db: DatabaseSync, code: string): GameRow | undefined {
  return db.prepare(`SELECT ${columns} FROM games WHERE room_code = ?`).get(code) as unknown as GameRow | undefined;
}
export function insertMove(db: DatabaseSync, move: MoveRow): void {
  db.prepare('INSERT INTO moves (game_id, seq, player, move, created_at) VALUES (?, ?, ?, ?, ?)').run(move.gameId, move.seq, move.player, JSON.stringify(move.move), move.createdAt);
}
export function listMoves(db: DatabaseSync, gameId: number): MoveRow[] {
  const rows = db.prepare('SELECT game_id AS gameId, seq, player, move, created_at AS createdAt FROM moves WHERE game_id = ? ORDER BY seq').all(gameId) as unknown as (Omit<MoveRow, 'move'> & { move: string })[];
  return rows.map(row => ({ ...row, move: JSON.parse(row.move) as unknown }));
}
export function listUserGames(db: DatabaseSync, userId: number): GameRow[] {
  return db.prepare(`SELECT ${columns} FROM games WHERE player0_user_id = ? OR player1_user_id = ? ORDER BY created_at DESC, id DESC`).all(userId, userId) as unknown as GameRow[];
}
