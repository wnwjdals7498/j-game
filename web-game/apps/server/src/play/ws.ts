import type { FastifyInstance } from 'fastify';
import type { WebSocket } from 'ws';
import type { ServerMessage } from '@jgame/protocol';
import { GameError, MatchService } from './match.js';
import { gameError } from './routes.js';

export class GamePresence {
  readonly games = new Map<number, Map<WebSocket, 0 | 1>>();
  online(id: number): [boolean, boolean] {
    const seats = [...(this.games.get(id)?.values() ?? [])];
    return [seats.includes(0), seats.includes(1)];
  }
}

export function registerPlayWebSocket(app: FastifyInstance, service: MatchService, presence: GamePresence): void {
  const games = presence.games;
  function send(socket: WebSocket, message: ServerMessage): void { if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(message)); }
  function broadcast(id: number): void {
    const subscribers = games.get(id); if (!subscribers?.size) return;
    const game = service.getView(id, presence.online(id));
    for (const socket of subscribers.keys()) send(socket, { type: 'state', game });
  }
  service.on('update', broadcast);
  app.addHook('onClose', async () => { games.clear(); service.off('update', broadcast); });
  app.get('/ws', { websocket: true }, (socket, request) => {
    const origin = request.headers.origin;
    let originValid = true;
    if (origin) { try { originValid = new URL(origin).host === request.headers.host; } catch { originValid = false; } }
    if (!request.user || !originValid) { send(socket, { type: 'error', code: 'unauthorized', message: 'Unauthorized' }); socket.close(); return; }
    const userId = request.user.id;
    const subscriptions = new Set<number>();
    socket.on('message', data => {
      try {
        let value: unknown;
        try { value = JSON.parse(data.toString()) as unknown; } catch { throw new GameError('bad_request', 'Invalid message'); }
        if (!value || typeof value !== 'object' || Array.isArray(value)) throw new GameError('bad_request', 'Invalid message');
        const m = value as Record<string, unknown>;
        if ((m.type !== 'subscribe' && m.type !== 'move' && m.type !== 'resign') || typeof m.gameId !== 'number' || !Number.isSafeInteger(m.gameId) || m.gameId < 1 || (m.type === 'move' && !('move' in m))) throw new GameError('bad_request', 'Invalid message');
        const seat = service.seatOf(m.gameId, userId);
        if (seat === null) throw new GameError('not_player', 'Not a player');
        if (m.type === 'subscribe') {
          let subscribers = games.get(m.gameId);
          if (!subscribers) { subscribers = new Map(); games.set(m.gameId, subscribers); }
          subscribers.set(socket, seat); subscriptions.add(m.gameId); broadcast(m.gameId);
        } else if (m.type === 'move') service.playMove(m.gameId, userId, m.move);
        else service.resign(m.gameId, userId);
      } catch (error) {
        const e = gameError(error); send(socket, { type: 'error', code: e.code, message: e.message });
      }
    });
    socket.on('close', () => { for (const id of subscriptions) { const subscribers = games.get(id); subscribers?.delete(socket); if (!subscribers?.size) games.delete(id); else broadcast(id); } });
  });
}
