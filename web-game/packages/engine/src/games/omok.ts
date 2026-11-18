import { IllegalMoveError } from '../types.js';
import type { GameRules, Outcome, Player } from '../types.js';

export const OMOK_SIZE = 15;
export type OmokMove = { x: number; y: number };
export interface OmokState {
  board: (Player | null)[];
  next: Player;
  moveCount: number;
  lastMove: OmokMove | null;
  winner: Player | null;
}

const inBounds = (x: number, y: number): boolean =>
  Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x < OMOK_SIZE && y >= 0 && y < OMOK_SIZE;

const outcome = (state: OmokState): Outcome => {
  if (state.winner !== null) return { kind: 'win', winner: state.winner };
  if (state.moveCount === OMOK_SIZE * OMOK_SIZE) return { kind: 'draw' };
  return { kind: 'ongoing' };
};

const isLegal = (state: OmokState, { x, y }: OmokMove): boolean =>
  outcome(state).kind === 'ongoing' && inBounds(x, y) && state.board[y * OMOK_SIZE + x] === null;

const hasFive = (board: (Player | null)[], { x, y }: OmokMove, player: Player): boolean => {
  const directions = [[1, 0], [0, 1], [1, 1], [1, -1]] as const;
  return directions.some(([dx, dy]) => {
    let count = 1;
    for (const sign of [-1, 1]) {
      let nx = x + dx * sign;
      let ny = y + dy * sign;
      while (inBounds(nx, ny) && board[ny * OMOK_SIZE + nx] === player) {
        count++;
        nx += dx * sign;
        ny += dy * sign;
      }
    }
    return count >= 5;
  });
};

export const omok: GameRules<OmokState, OmokMove> = {
  id: 'omok',
  initialState: () => ({ board: Array<Player | null>(OMOK_SIZE * OMOK_SIZE).fill(null), next: 0, moveCount: 0, lastMove: null, winner: null }),
  currentPlayer: (state) => state.next,
  isLegal,
  legalMoves: (state) => {
    if (outcome(state).kind !== 'ongoing') return [];
    const moves: OmokMove[] = [];
    for (let y = 0; y < OMOK_SIZE; y++) {
      for (let x = 0; x < OMOK_SIZE; x++) {
        if (state.board[y * OMOK_SIZE + x] === null) moves.push({ x, y });
      }
    }
    return moves;
  },
  applyMove: (state, move) => {
    if (!isLegal(state, move)) throw new IllegalMoveError();
    const board = [...state.board];
    board[move.y * OMOK_SIZE + move.x] = state.next;
    return {
      board,
      next: state.next === 0 ? 1 : 0,
      moveCount: state.moveCount + 1,
      lastMove: { ...move },
      winner: hasFive(board, move, state.next) ? state.next : null,
    };
  },
  outcome,
};
