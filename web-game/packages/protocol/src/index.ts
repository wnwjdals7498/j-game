import type { BotLevel, Outcome } from '@jgame/engine';

export interface UserView { id: number; name: string; isQa: boolean; provider: string }
export type ProviderInfo = { id: 'google'; kind: 'gis'; clientId: string } | { id: 'kakao' | 'naver' | 'github'; kind: 'redirect'; startUrl: string } | { id: 'qa'; kind: 'qa' };
export type PlayerView = { kind: 'human'; userId: number; name: string; isQa: boolean } | { kind: 'bot'; level: BotLevel };
export interface GameView { id: number; gameId: string; mode: 'pvp' | 'pvc'; status: 'waiting' | 'playing' | 'finished'; roomCode: string | null; players: [PlayerView | null, PlayerView | null]; state: unknown; outcome: Outcome; endReason: 'rules' | 'resign' | null; moveCount: number; online: [boolean, boolean] }
export interface HistoryItem { id: number; gameId: string; mode: 'pvp' | 'pvc'; opponentName: string; result: 'win' | 'loss' | 'draw' | 'ongoing'; createdAt: string }
export type ErrorCode = 'unauthorized' | 'not_found' | 'not_player' | 'not_your_turn' | 'illegal_move' | 'game_finished' | 'room_full' | 'bad_request';
export type ClientMessage = { type: 'subscribe'; gameId: number } | { type: 'move'; gameId: number; move: unknown } | { type: 'resign'; gameId: number };
export type ServerMessage = { type: 'state'; game: GameView } | { type: 'error'; code: ErrorCode; message: string };
