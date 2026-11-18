import { OMOK_SIZE } from '@jgame/engine';
import type { OmokState } from '@jgame/engine';
import type { BoardProps } from './index';

export function OmokBoard({ state, myTurn, onMove }: BoardProps) {
  const game = state as OmokState;
  const spacing = 30, margin = 20, size = margin * 2 + spacing * (OMOK_SIZE - 1);
  return <svg className="board" viewBox={`0 0 ${size} ${size}`} role="img" aria-label="오목판">
    <rect width={size} height={size} fill="#d7a962" />
    {Array.from({ length: OMOK_SIZE }, (_, i) => <g key={i} stroke="#42301c" strokeWidth="1"><line x1={margin} y1={margin + i * spacing} x2={size - margin} y2={margin + i * spacing} /><line x1={margin + i * spacing} y1={margin} x2={margin + i * spacing} y2={size - margin} /></g>)}
    {game.board.map((stone, i) => {
      const x = i % OMOK_SIZE, y = Math.floor(i / OMOK_SIZE), cx = margin + x * spacing, cy = margin + y * spacing;
      const last = game.lastMove?.x === x && game.lastMove.y === y;
      return <g key={i} data-cell={`${x},${y}`} data-stone={stone === null ? '' : String(stone)} onClick={() => { if (myTurn && stone === null) onMove({ x, y }); }}>
        <rect x={cx - spacing / 2} y={cy - spacing / 2} width={spacing} height={spacing} fill="transparent" />
        {stone !== null && <circle cx={cx} cy={cy} r="13" fill={stone === 0 ? '#171717' : '#fff'} stroke="#333" />}
        {last && <circle cx={cx} cy={cy} r="3" fill={stone === 0 ? '#fff' : '#b52222'} />}
      </g>;
    })}
  </svg>;
}
