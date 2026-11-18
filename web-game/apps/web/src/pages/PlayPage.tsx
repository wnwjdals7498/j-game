import { useState } from 'react';
import type { GameView, UserView } from '@jgame/protocol';
import { api } from '../api';
import { boards } from '../boards';
import { useGameSocket } from '../useGameSocket';
export function PlayPage({ id, user }: { id: number; user: UserView }) {
  const { game, error, connected, send } = useGameSocket(id);
  const [rematching, setRematching] = useState(false);
  const [rematchError, setRematchError] = useState('');
  if (!game) return <main><p>연결 중…</p>{error && <p role="alert">{error === 'disconnected' ? '연결이 끊겨 전송하지 못했습니다' : `대국을 불러오지 못했습니다: ${error}`}</p>}<a href="#/games">게임 목록</a></main>;
  const seatIndex = game.players.findIndex(player => player?.kind === 'human' && player.userId === user.id);
  const seat = seatIndex === 0 || seatIndex === 1 ? seatIndex : null;
  const opponent = seat === null ? null : game.players[seat === 0 ? 1 : 0];
  const myTurn = connected && game.status === 'playing' && seat !== null && game.turn === seat;
  const board = boards[game.gameId];
  const result = game.outcome.kind === 'draw' ? '무승부' : game.outcome.kind === 'win' ? game.outcome.winner === seat ? '승리' : '패배' : '';
  const rematch = () => {
    if (seat === null || rematching) return;
    setRematching(true); setRematchError('');
    const body = { gameId: game.gameId, seat };
    const request = game.mode === 'pvc' && opponent?.kind === 'bot'
      ? api<{ game: GameView }>('/api/games/pvc', { ...body, botLevel: opponent.level })
      : game.mode === 'pvp' ? api<{ game: GameView }>('/api/rooms', body) : Promise.reject(new Error('상대 정보를 찾을 수 없습니다.'));
    void request.then(({ game: next }) => { location.hash = `#/play/${next.id}`; }).catch(() => { setRematchError('새 대국을 만들지 못했습니다.'); setRematching(false); });
  };
  return <main><h1>{board?.title ?? game.gameId}</h1>{!connected && <p>연결 중…</p>}{game.status === 'waiting' ? <p>상대를 기다리는 중입니다. 방 코드: <strong>{game.roomCode}</strong></p> : game.status === 'playing' && connected && <p>{myTurn ? '내 차례' : '상대 차례'}</p>}
    {opponent && <p>상대: {opponent.kind === 'bot' ? '컴퓨터' : opponent.name} {opponent.kind === 'human' && opponent.isQa && <span className="qa-badge">QA</span>} {opponent.kind === 'human' && seat !== null ? (game.online[seat === 0 ? 1 : 0] ? '(연결됨)' : '(연결 끊김)') : ''}</p>}
    {board && <board.Board state={game.state} mySeat={seat} myTurn={myTurn} onMove={move => send({ type: 'move', gameId: id, move })} />}
    {error && <p role="alert">{error === 'disconnected' ? '연결이 끊겨 전송하지 못했습니다' : `요청을 처리하지 못했습니다: ${error}`}</p>}
    {game.status !== 'finished' && <button disabled={!connected} onClick={() => send({ type: 'resign', gameId: id })}>기권</button>}
    {game.status === 'finished' && <section><h2>{result}</h2><div className="actions"><button disabled={rematching || seat === null} onClick={rematch}>다시 하기</button><a className="button" href={`#/lobby/${game.gameId}`}>로비로</a></div>{rematchError && <p role="alert">{rematchError}</p>}</section>}
  </main>;
}
