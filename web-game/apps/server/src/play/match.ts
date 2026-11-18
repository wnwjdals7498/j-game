import { EventEmitter } from 'node:events';
import type { DatabaseSync } from 'node:sqlite';
import { chooseBotMove, createRng, getRules } from '@jgame/engine';
import type { BotLevel, GameRules, Outcome, Player } from '@jgame/engine';
import type { ErrorCode, GameView, PlayerView } from '@jgame/protocol';
import { findGameByRoomCode, getGame, insertGame, insertMove, listMoves, updateGame } from '../repos/games.js';
import type { GameRow } from '../repos/games.js';
import { getUser } from '../repos/users.js';
import { generateRoomCode } from './roomCode.js';

export class GameError extends Error {
  constructor(public code: ErrorCode, message: string) { super(message); this.name = 'GameError'; }
}
export type SeatChoice = 0 | 1 | 'random';

type Cached = { state: unknown; moveCount: number };
export class MatchService extends EventEmitter {
  private cache = new Map<number, Cached>();
  private pending = new Map<number, Promise<void>>();
  private rng: () => number;
  private timers = new Map<number, { timer: NodeJS.Timeout; resolve: () => void }>();
  private closed = false;
  constructor(private db: DatabaseSync, private opts: { botDelayMs: number; rng?: () => number }) {
    super(); this.rng = opts.rng ?? Math.random;
  }
  private rules(id: string): GameRules<unknown, unknown, unknown> {
    const rules = getRules(id);
    if (!rules) throw new GameError('not_found', 'Game not found');
    return rules;
  }
  private game(id: number): GameRow {
    const game = getGame(this.db, id);
    if (!game) throw new GameError('not_found', 'Game not found');
    return game;
  }
  private seat(choice: SeatChoice): Player { return choice === 'random' ? (this.rng() < 0.5 ? 0 : 1) : choice; }
  private state(game: GameRow): Cached {
    let cached = this.cache.get(game.id);
    if (!cached) {
      const rules = this.rules(game.gameId);
      let state = rules.initialState(undefined);
      const moves = listMoves(this.db, game.id);
      for (const move of moves) state = rules.applyMove(state, move.move);
      cached = { state, moveCount: moves.length };
      this.cache.set(game.id, cached);
    }
    return cached;
  }
  private create(userId: number, gameId: string, seat: Player, mode: 'pvp' | 'pvc', roomCode: string | null, botLevel: BotLevel | null, botSeed: number | null): GameRow {
    this.rules(gameId);
    return insertGame(this.db, { gameId, mode, roomCode, player0UserId: seat === 0 ? userId : null, player1UserId: seat === 1 ? userId : null, botLevel, botSeed, status: mode === 'pvp' ? 'waiting' : 'playing', endReason: null, resignedBy: null, createdAt: new Date().toISOString(), endedAt: null });
  }
  createPvc(userId: number, p: { gameId: string; seat: SeatChoice; botLevel: BotLevel; seed?: number }): GameView {
    this.rules(p.gameId);
    const seat = this.seat(p.seat);
    const game = this.create(userId, p.gameId, seat, 'pvc', null, p.botLevel, p.seed ?? Math.floor(this.rng() * 2 ** 31));
    return this.getView(game.id);
  }
  createRoom(userId: number, p: { gameId: string; seat: SeatChoice }): GameView {
    this.rules(p.gameId);
    const seat = this.seat(p.seat);
    for (let i = 0; i < 10; i++) {
      const code = generateRoomCode(this.rng);
      if (!findGameByRoomCode(this.db, code)) return this.getView(this.create(userId, p.gameId, seat, 'pvp', code, null, null).id);
    }
    throw new Error('Could not generate a unique room code');
  }
  joinRoom(userId: number, roomCode: string): GameView {
    const game = findGameByRoomCode(this.db, roomCode);
    if (!game) throw new GameError('not_found', 'Room not found');
    if (game.player0UserId === userId || game.player1UserId === userId) return this.getView(game.id);
    if (game.player0UserId !== null && game.player1UserId !== null) throw new GameError('room_full', 'Room is full');
    if (game.status === 'finished') throw new GameError('game_finished', 'Game is finished');
    if (game.player0UserId === null) game.player0UserId = userId; else game.player1UserId = userId;
    game.status = 'playing'; updateGame(this.db, game); this.emit('update', game.id);
    return this.getView(game.id);
  }
  seatOf(gameDbId: number, userId: number): Player | null {
    const game = this.game(gameDbId);
    return game.player0UserId === userId ? 0 : game.player1UserId === userId ? 1 : null;
  }
  private apply(game: GameRow, player: Player, move: unknown): void {
    const rules = this.rules(game.gameId); const cached = this.state(game);
    let legal = false;
    try { legal = rules.isLegal(cached.state, move); } catch { /* malformed move */ }
    if (!legal) throw new GameError('illegal_move', 'Illegal move');
    const state = rules.applyMove(cached.state, move);
    const outcome = rules.outcome(state);
    this.db.exec('BEGIN');
    try {
      insertMove(this.db, { gameId: game.id, seq: cached.moveCount, player, move, createdAt: new Date().toISOString() });
      if (outcome.kind !== 'ongoing') {
        game.status = 'finished'; game.endReason = 'rules'; game.endedAt = new Date().toISOString(); updateGame(this.db, game);
      }
      this.db.exec('COMMIT');
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
    cached.state = state; cached.moveCount++;
  }
  playMove(gameDbId: number, userId: number, move: unknown): GameView {
    const game = this.game(gameDbId); const seat = this.seatOf(gameDbId, userId);
    if (seat === null) throw new GameError('not_player', 'Not a player');
    if (game.status === 'finished') throw new GameError('game_finished', 'Game is finished');
    if (game.status !== 'playing' || this.rules(game.gameId).currentPlayer(this.state(game).state) !== seat) throw new GameError('not_your_turn', 'Not your turn');
    this.apply(game, seat, move); this.emit('update', game.id);
    return this.getView(game.id);
  }
  resign(gameDbId: number, userId: number): GameView {
    const game = this.game(gameDbId); const seat = this.seatOf(gameDbId, userId);
    if (seat === null) throw new GameError('not_player', 'Not a player');
    if (game.status === 'finished') throw new GameError('game_finished', 'Game is finished');
    game.status = 'finished'; game.endReason = 'resign'; game.resignedBy = seat; game.endedAt = new Date().toISOString();
    updateGame(this.db, game); this.emit('update', game.id); return this.getView(game.id);
  }
  getView(gameDbId: number, online: [boolean, boolean] = [false, false]): GameView {
    const game = this.game(gameDbId); const cached = this.state(game); const rules = this.rules(game.gameId);
    const player = (id: number | null): PlayerView | null => {
      if (id !== null) {
        const user = getUser(this.db, id);
        if (!user) throw new Error('Game player not found');
        return { kind: 'human', userId: user.id, name: user.name, isQa: user.isQa };
      }
      return game.mode === 'pvc' ? { kind: 'bot', level: game.botLevel as BotLevel } : null;
    };
    const outcome: Outcome = game.endReason === 'resign' ? { kind: 'win', winner: game.resignedBy === 0 ? 1 : 0 } : rules.outcome(cached.state);
    const view: GameView = { id: game.id, gameId: game.gameId, mode: game.mode, status: game.status, turn: game.status === 'playing' ? rules.currentPlayer(cached.state) : null, roomCode: game.roomCode, players: [player(game.player0UserId), player(game.player1UserId)], state: structuredClone(cached.state), outcome, endReason: game.endReason, moveCount: cached.moveCount, online };
    this.scheduleBot(game, cached);
    return view;
  }
  private scheduleBot(game: GameRow, cached: Cached): void {
    if (this.closed || game.mode !== 'pvc' || game.status !== 'playing' || this.pending.has(game.id)) return;
    const rules = this.rules(game.gameId); const turn = rules.currentPlayer(cached.state);
    if ((turn === 0 ? game.player0UserId : game.player1UserId) !== null) return;
    const promise = new Promise<void>(resolve => {
      const timer = setTimeout(() => {
        this.timers.delete(game.id);
        let moved = false;
        try {
          const current = this.game(game.id);
          if (current.status === 'playing') {
            const state = this.state(current);
            const move = chooseBotMove(rules, state.state, current.botLevel as BotLevel, createRng(current.botSeed! + Math.floor(state.moveCount / 2)));
            this.apply(current, turn, move); moved = true; this.emit('update', current.id);
          }
        } catch (error) { console.error('Bot move failed:', error); }
        finally {
          this.pending.delete(game.id);
          try {
            if (moved) {
              const current = this.game(game.id);
              this.scheduleBot(current, this.state(current));
            }
          } catch (error) { console.error('Bot scheduling failed:', error); }
          resolve();
        }
      }, this.opts.botDelayMs);
      this.timers.set(game.id, { timer, resolve });
    });
    this.pending.set(game.id, promise);
  }
  close(): void {
    this.closed = true;
    for (const { timer, resolve } of this.timers.values()) { clearTimeout(timer); resolve(); }
    this.timers.clear();
    this.pending.clear();
  }
  async whenIdle(): Promise<void> {
    while (this.pending.size > 0) await Promise.all(this.pending.values());
  }
}
