import type { GameRules } from './types.js';

export type BotLevel = 'random' | 'basic';

export function createRng(seed: number): () => number {
  seed |= 0;
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let value = seed;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

export function chooseBotMove<S, M>(
  rules: Omit<GameRules<S, M>, 'initialState'>,
  state: S,
  level: BotLevel,
  rng: () => number,
): M {
  const moves = rules.legalMoves(state);
  if (moves.length === 0) throw new Error('No legal moves');

  let candidates = moves;
  if (level === 'basic') {
    const player = rules.currentPlayer(state);
    for (const move of moves) {
      const outcome = rules.outcome(rules.applyMove(state, move));
      if (outcome.kind === 'win' && outcome.winner === player) return move;
    }
    const safeMoves = moves.filter((move) => {
      const next = rules.applyMove(state, move);
      const opponent = rules.currentPlayer(next);
      return !rules.legalMoves(next).some((reply) => {
        const outcome = rules.outcome(rules.applyMove(next, reply));
        return outcome.kind === 'win' && outcome.winner === opponent;
      });
    });
    if (safeMoves.length > 0) candidates = safeMoves;
  }
  return candidates[Math.floor(rng() * candidates.length)]!;
}
