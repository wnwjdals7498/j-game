import { useState } from 'react';
import type { GameView } from '@jgame/protocol';
import { api } from '../api';
import { boards } from '../boards';
type Seat = '0' | '1' | 'random';
export function LobbyPage({ gameId }: { gameId: string }) {
  const [seat, setSeat] = useState<Seat>('random'); const [botLevel, setBotLevel] = useState<'random' | 'basic'>('basic'); const [roomCode, setRoomCode] = useState(''); const [error, setError] = useState('');
  const start = (path: string, body: unknown) => { void api<{ game: GameView }>(path, body).then(({ game }) => { location.hash = `#/play/${game.id}`; }).catch(() => setError('대국을 시작하지 못했습니다.')); };
  const choice = seat === 'random' ? seat : Number(seat);
  return <main><h1>{boards[gameId]?.title ?? gameId} 로비</h1><label>색 <select value={seat} onChange={e => setSeat(e.target.value as Seat)}><option value="0">흑</option><option value="1">백</option><option value="random">무작위</option></select></label><div className="stack"><label>컴퓨터 수준 <select value={botLevel} onChange={e => setBotLevel(e.target.value as 'random' | 'basic')}><option value="random">무작위</option><option value="basic">기본</option></select></label><button onClick={() => start('/api/games/pvc', { gameId, seat: choice, botLevel })}>컴퓨터와 두기</button><button onClick={() => start('/api/rooms', { gameId, seat: choice })}>방 만들기</button><form onSubmit={e => { e.preventDefault(); start('/api/rooms/join', { roomCode }); }}><label>방 코드 <input value={roomCode} maxLength={6} required onChange={e => setRoomCode(e.target.value.toUpperCase())} /></label><button>방 코드로 들어가기</button></form></div>{error && <p role="alert">{error}</p>}<p><a href="#/games">게임 목록</a></p></main>;
}
