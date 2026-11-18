export type Player = 0 | 1;

export type Outcome =
  | { kind: 'ongoing' }
  | { kind: 'win'; winner: Player }
  | { kind: 'draw' };

export interface GameRules<State, Move, Options = void> {
  id: string;
  initialState(options: Options): State;
  currentPlayer(state: State): Player;
  isLegal(state: State, move: Move): boolean;
  legalMoves(state: State): Move[];
  applyMove(state: State, move: Move): State;
  outcome(state: State): Outcome;
}

export class IllegalMoveError extends Error {
  constructor() {
    super('Illegal move');
    this.name = 'IllegalMoveError';
  }
}
