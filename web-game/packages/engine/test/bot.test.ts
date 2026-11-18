import { expect, test } from 'vitest';
import { chooseBotMove, createRng, getRules, omok } from '../src/index.js';
import type { BotLevel, OmokMove } from '../src/index.js';

const play = (moves: [number, number][]) =>
  moves.reduce((state, [x, y]) => omok.applyMove(state, { x, y }), omok.initialState());

const botGame = (seed: number, levels: [BotLevel, BotLevel]): OmokMove[] => {
  let state = omok.initialState();
  const rng = createRng(seed);
  const moves: OmokMove[] = [];
  while (omok.outcome(state).kind === 'ongoing') {
    const move = chooseBotMove(omok, state, levels[omok.currentPlayer(state)], rng);
    expect(omok.isLegal(state, move)).toBe(true);
    state = omok.applyMove(state, move);
    moves.push(move);
  }
  expect(['win', 'draw']).toContain(omok.outcome(state).kind);
  return moves;
};

test('same seed gives same random game', () => {
  expect(botGame(42, ['random', 'random'])).toEqual(botGame(42, ['random', 'random']));
});

test('basic takes an immediate win', () => {
  const state = play([[0,0],[0,5],[1,0],[1,5],[2,0],[2,5],[3,0],[3,5]]);
  expect(chooseBotMove(omok, state, 'basic', createRng(1))).toEqual({ x: 4, y: 0 });
});

test("basic blocks opponent's immediate win", () => {
  const state = play([[0,0],[0,5],[2,1],[1,5],[4,2],[2,5],[6,3],[3,5]]);
  expect(chooseBotMove(omok, state, 'basic', createRng(1))).toEqual({ x: 4, y: 5 });
});

test('bot vs bot games always finish with legal moves', () => {
  for (let seed = 1; seed <= 30; seed++) {
    botGame(seed, seed % 2 ? ['random', 'basic'] : ['basic', 'random']);
  }
}, 120_000);

test('getRules returns undefined for unknown game', () => {
  expect(getRules('omok')?.id).toBe('omok');
  expect(getRules('nope')).toBeUndefined();
});
