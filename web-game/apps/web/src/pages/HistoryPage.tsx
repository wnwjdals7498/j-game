import { useEffect, useState } from 'react';
import type { HistoryItem } from '@jgame/protocol';
import { api } from '../api';
import { boards } from '../boards';
export function HistoryPage() {
  const [games, setGames] = useState<HistoryItem[]>([]); const [error, setError] = useState('');
  useEffect(() => { let active = true; void api<{ games: HistoryItem[] }>('/api/me/games').then(data => { if (active) setGames(data.games); }).catch(() => { if (active) setError('기록을 불러오지 못했습니다.'); }); return () => { active = false; }; }, []);
  const labels = { win: '승리', loss: '패배', draw: '무승부', ongoing: '진행 중' };
  return <main><h1>내 기록</h1>{error && <p role="alert">{error}</p>}{games.length === 0 && !error && <p>기록이 없습니다.</p>}<ul>{games.map(game => <li key={game.id}><a href={`#/play/${game.id}`}>{boards[game.gameId]?.title ?? game.gameId} · {game.opponentName || '대기 중'} · {labels[game.result]} · {game.createdAt}</a></li>)}</ul><a href="#/games">게임 목록</a></main>;
}
