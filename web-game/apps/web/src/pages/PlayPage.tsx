import type { UserView } from '@jgame/protocol';
import type { OmokState } from '@jgame/engine';
import { boards } from '../boards';
import { useGameSocket } from '../useGameSocket';
export function PlayPage({ id, user }: { id: number; user: UserView }) {
  const { game, error, send } = useGameSocket(id);
  if (!game) return <main><p>{error ? `대국을 불러오지 못했습니다: ${error}` : '대국에 연결하는 중입니다.'}</p><a href="#/games">게임 목록</a></main>;
  const seatIndex = game.players.findIndex(player => player?.kind === 'human' && player.userId === user.id);
  const seat = seatIndex === 0 || seatIndex === 1 ? seatIndex : null;
  const opponent = seat === null ? null : game.players[seat === 0 ? 1 : 0];
  const myTurn = game.status === 'playing' && seat !== null && (game.state as OmokState).next === seat;
  const board = boards[game.gameId];
  const result = game.outcome.kind === 'draw' ? '무승부' : game.outcome.kind === 'win' ? game.outcome.winner === seat ? '승리' : '패배' : '';
  return <main><h1>{board?.title ?? game.gameId}</h1>{game.status === 'waiting' ? <p>상대를 기다리는 중입니다. 방 코드: <strong>{game.roomCode}</strong></p> : game.status === 'playing' && <p>{myTurn ? '내 차례' : '상대 차례'}</p>}
    {opponent && <p>상대: {opponent.kind === 'bot' ? '컴퓨터' : opponent.name} {opponent.kind === 'human' && seat !== null ? (game.online[seat === 0 ? 1 : 0] ? '(연결됨)' : '(연결 끊김)') : ''}</p>}
    {board && <board.Board state={game.state} mySeat={seat} myTurn={myTurn} onMove={move => send({ type: 'move', gameId: id, move })} />}
    {error && <p role="alert">요청을 처리하지 못했습니다: {error}</p>}
    {game.status !== 'finished' && <button onClick={() => send({ type: 'resign', gameId: id })}>기권</button>}
    {game.status === 'finished' && <section><h2>{result}</h2><div className="actions"><a className="button" href={`#/lobby/${game.gameId}`}>다시 하기</a><a className="button" href={`#/lobby/${game.gameId}`}>로비로</a></div></section>}
  </main>;
}
