export { IllegalMoveError } from './types.js';
export type { GameRules, Outcome, Player } from './types.js';
export { OMOK_SIZE, omok } from './games/omok.js';
export type { OmokMove, OmokState } from './games/omok.js';
export { chooseBotMove, createRng } from './bot.js';
export type { BotLevel } from './bot.js';
export { games, getRules } from './registry.js';
export type { GameId } from './registry.js';
