import { boards } from '../boards';
export function GameListPage() { return <main><h1>게임 목록</h1><div className="stack">{Object.entries(boards).map(([id, board]) => <a className="button" key={id} href={`#/lobby/${id}`}>{board.title}</a>)}</div><p><a href="#/history">내 기록</a></p></main>; }
