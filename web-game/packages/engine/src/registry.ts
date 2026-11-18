import { omok } from './games/omok.js';
import type { GameRules } from './types.js';

export const games = { omok };
export type GameId = keyof typeof games;

export function getRules(id: string): GameRules<unknown, unknown, unknown> | undefined {
  if (!Object.hasOwn(games, id)) return undefined;
  return games[id as GameId] as unknown as GameRules<unknown, unknown, unknown>;
}
