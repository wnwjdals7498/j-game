import { expect, test } from 'vitest';
import { IllegalMoveError, omok } from '../src/index.js';
import type { OmokMove } from '../src/index.js';

const play = (moves: [number, number][]) =>
  moves.reduce((s, [x, y]) => omok.applyMove(s, { x, y }), omok.initialState());

test('black moves first on empty 15x15 board', () => {
  const s = omok.initialState();
  expect(s.board).toHaveLength(225);
  expect(omok.currentPlayer(s)).toBe(0);
  expect(omok.legalMoves(s)).toHaveLength(225);
});
test('horizontal five wins', () => {
  const s = play([[0,0],[0,1],[1,0],[1,1],[2,0],[2,1],[3,0],[3,1],[4,0]]);
  expect(omok.outcome(s)).toEqual({ kind: 'win', winner: 0 });
});
test('vertical five wins for white', () => {
  const s = play([[5,5],[0,0],[6,5],[0,1],[7,5],[0,2],[8,5],[0,3],[10,10],[0,4]]);
  expect(omok.outcome(s)).toEqual({ kind: 'win', winner: 1 });
});
test('diagonal five wins', () => {
  const s = play([[0,0],[0,14],[1,1],[1,14],[2,2],[2,14],[3,3],[3,14],[4,4]]);
  expect(omok.outcome(s)).toEqual({ kind: 'win', winner: 0 });
});
test('anti-diagonal five wins', () => {
  const s = play([[4,0],[0,10],[3,1],[1,10],[2,2],[2,10],[1,3],[3,10],[0,4]]);
  expect(omok.outcome(s)).toEqual({ kind: 'win', winner: 0 });
});
test('six in a row also wins', () => {
  const s = play([[0,0],[0,5],[1,0],[1,5],[2,0],[2,5],[4,0],[3,5],[5,0],[5,5],[3,0]]);
  expect(omok.outcome(s)).toEqual({ kind: 'win', winner: 0 });
});
test('four in a row is still ongoing', () => {
  const s = play([[0,0],[0,1],[1,0],[1,1],[2,0],[2,1],[3,0]]);
  expect(omok.outcome(s)).toEqual({ kind: 'ongoing' });
});
test('full board without five is a draw', () => {
  const cells: [number, number][][] = [[], []];
  for (let y = 0; y < 15; y++) for (let x = 0; x < 15; x++) cells[((x >> 1) + y) % 2]!.push([x, y]);
  const moves: [number, number][] = [];
  for (let i = 0; i < 113; i++) {
    moves.push(cells[0]![i]!);
    if (i < 112) moves.push(cells[1]![i]!);
  }
  const s = play(moves);
  expect(s.moveCount).toBe(225);
  expect(omok.outcome(s)).toEqual({ kind: 'draw' });
});
test('occupied cell is illegal and applyMove throws', () => {
  const s = play([[7,7]]);
  expect(omok.isLegal(s, { x: 7, y: 7 })).toBe(false);
  expect(() => omok.applyMove(s, { x: 7, y: 7 })).toThrow(IllegalMoveError);
});
test('out of range and non-integer moves are illegal', () => {
  for (const m of [{x:-1,y:0},{x:15,y:0},{x:0,y:15},{x:1.5,y:2}])
    expect(omok.isLegal(omok.initialState(), m)).toBe(false);
});
test('no moves are legal after a win', () => {
  const s = play([[0,0],[0,1],[1,0],[1,1],[2,0],[2,1],[3,0],[3,1],[4,0]]);
  expect(omok.legalMoves(s)).toHaveLength(0);
  expect(omok.isLegal(s, { x: 10, y: 10 })).toBe(false);
});
test('applyMove does not mutate the input state', () => {
  const s = play([[7,7]]);
  const before = { ...s, board: [...s.board], lastMove: s.lastMove && { ...s.lastMove } };
  const move: OmokMove = { x: 8, y: 8 };
  const next = omok.applyMove(s, move);
  expect(s).toEqual(before);
  expect(next.board).not.toBe(s.board);
  expect(next.board[8 * 15 + 8]).toBe(1);
});
