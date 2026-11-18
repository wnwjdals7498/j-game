import type { JSX } from 'react';
import { OmokBoard } from './OmokBoard';
export interface BoardProps { state: unknown; mySeat: 0 | 1 | null; myTurn: boolean; onMove: (move: unknown) => void }
export const boards: Record<string, { title: string; Board: (p: BoardProps) => JSX.Element }> = { omok: { title: '오목', Board: OmokBoard } };
