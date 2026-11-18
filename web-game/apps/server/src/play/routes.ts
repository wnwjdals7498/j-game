import type { DatabaseSync } from 'node:sqlite';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type { ErrorCode, GameView, HistoryItem } from '@jgame/protocol';
import type { GamePresence } from './ws.js';
import { requireUser } from '../auth/session.js';
import { listUserGames } from '../repos/games.js';
import { GameError, MatchService, type SeatChoice } from './match.js';

export function gameError(error: unknown): GameError {
  if (error instanceof GameError) return error;
  throw error;
}
export function errorStatus(code: ErrorCode): number {
  if (code === 'not_found') return 404;
  if (code === 'bad_request' || code === 'illegal_move') return 400;
  if (code === 'not_player') return 403;
  if (code === 'unauthorized') return 401;
  return 409;
}
function bodyObject(body: unknown): Record<string, unknown> {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new GameError('bad_request', 'Invalid body');
  return body as Record<string, unknown>;
}
function seatOf(value: unknown): SeatChoice {
  if (value !== 0 && value !== 1 && value !== 'random') throw new GameError('bad_request', 'Invalid seat');
  return value;
}
function playUser(request: FastifyRequest, reply: FastifyReply) {
  if (!request.user) { void reply.code(401).send({ code: 'unauthorized', message: 'Unauthorized' }); return undefined; }
  return requireUser(request, reply);
}
export function registerPlayRoutes(app: FastifyInstance, db: DatabaseSync, service: MatchService, presence: GamePresence): void {
  const withOnline = (game: GameView): GameView => ({ ...game, online: presence.online(game.id) });
  app.setErrorHandler((error, request, reply) => {
    if (!(error instanceof GameError) && typeof error === 'object' && error !== null && 'statusCode' in error && error.statusCode === 400 && /^\/api\/(?:games(?:\/|$)|rooms(?:\/|$)|me\/games(?:\?|$))/.test(request.url)) return reply.code(400).send({ code: 'bad_request', message: 'Invalid request' });
    if (error instanceof GameError) return reply.code(errorStatus(error.code)).send({ code: error.code, message: error.message });
    return reply.send(error);
  });
  app.post('/api/games/pvc', async (request, reply) => {
    const user = playUser(request, reply); if (!user) return reply;
    const p = bodyObject(request.body); const seat = seatOf(p.seat);
    if (typeof p.gameId !== 'string' || (p.botLevel !== 'random' && p.botLevel !== 'basic') || (p.seed !== undefined && (typeof p.seed !== 'number' || !Number.isSafeInteger(p.seed)))) throw new GameError('bad_request', 'Invalid game settings');
    return reply.code(201).send({ game: withOnline(service.createPvc(user.id, { gameId: p.gameId, seat, botLevel: p.botLevel, ...(p.seed === undefined ? {} : { seed: p.seed as number }) })) });
  });
  app.post('/api/rooms', async (request, reply) => {
    const user = playUser(request, reply); if (!user) return reply;
    const p = bodyObject(request.body); const seat = seatOf(p.seat);
    if (typeof p.gameId !== 'string') throw new GameError('bad_request', 'Invalid game');
    return reply.code(201).send({ game: withOnline(service.createRoom(user.id, { gameId: p.gameId, seat })) });
  });
  app.post('/api/rooms/join', async (request, reply) => {
    const user = playUser(request, reply); if (!user) return reply;
    const p = bodyObject(request.body);
    if (typeof p.roomCode !== 'string') throw new GameError('bad_request', 'Invalid room code');
    return { game: withOnline(service.joinRoom(user.id, p.roomCode.toUpperCase())) };
  });
  app.get<{ Params: { id: string } }>('/api/games/:id', async (request, reply) => {
    const user = playUser(request, reply); if (!user) return reply;
    const id = Number(request.params.id);
    if (!Number.isSafeInteger(id) || id < 1) throw new GameError('bad_request', 'Invalid game id');
    if (service.seatOf(id, user.id) === null) throw new GameError('not_player', 'Not a player');
    return { game: service.getView(id, presence.online(id)) };
  });
  app.get('/api/me/games', async (request, reply) => {
    const user = playUser(request, reply); if (!user) return reply;
    const games: HistoryItem[] = listUserGames(db, user.id).slice(0, 50).map(row => {
      const view = service.getView(row.id); const seat = row.player0UserId === user.id ? 0 : 1;
      const opponent = view.players[seat === 0 ? 1 : 0];
      const result = view.status !== 'finished' || view.outcome.kind === 'ongoing' ? 'ongoing' : view.outcome.kind === 'draw' ? 'draw' : view.outcome.winner === seat ? 'win' : 'loss';
      return { id: row.id, gameId: row.gameId, mode: row.mode, opponentName: opponent?.kind === 'human' ? opponent.name : opponent?.kind === 'bot' ? 'Bot' : '', result, createdAt: row.createdAt };
    });
    return { games };
  });
}
