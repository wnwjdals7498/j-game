import { useCallback, useEffect, useState } from 'react';
import type { UserView } from '@jgame/protocol';
import { api } from './api';
import { LoginPage } from './pages/LoginPage';
import { GameListPage } from './pages/GameListPage';
import { LobbyPage } from './pages/LobbyPage';
import { PlayPage } from './pages/PlayPage';
import { HistoryPage } from './pages/HistoryPage';
export function App() {
  const [user, setUser] = useState<UserView | null>(null); const [loading, setLoading] = useState(true); const [route, setRoute] = useState(location.hash || '#/games');
  useEffect(() => { const change = () => setRoute(location.hash || '#/games'); window.addEventListener('hashchange', change); return () => window.removeEventListener('hashchange', change); }, []);
  useEffect(() => { let active = true; void api<{ user: UserView }>('/api/me').then(data => { if (active) setUser(data.user); }).catch(() => { if (active) { setUser(null); location.hash = '#/login'; } }).finally(() => { if (active) setLoading(false); }); return () => { active = false; }; }, []);
  useEffect(() => { if (!loading && !user && route !== '#/login') location.hash = '#/login'; }, [loading, user, route]);
  const login = useCallback((value: UserView) => { setUser(value); location.hash = '#/games'; }, []);
  if (loading) return <main>불러오는 중입니다.</main>;
  if (!user) return <LoginPage onLogin={login} />;
  const parts = route.slice(2).split('/');
  let page = <GameListPage />;
  if (parts[0] === 'history') page = <HistoryPage />;
  else if (parts[0] === 'lobby' && parts[1]) page = <LobbyPage gameId={parts[1]} />;
  else if (parts[0] === 'play' && parts[1] && Number.isSafeInteger(Number(parts[1])) && Number(parts[1]) > 0) page = <PlayPage key={parts[1]} id={Number(parts[1])} user={user} />;
  return <><header><a href="#/games">전통 보드게임</a><span>{user.name}</span><a href="#/history">내 기록</a><button onClick={() => { void fetch('/api/auth/logout', { method: 'POST' }).then(() => { setUser(null); location.hash = '#/login'; }); }}>로그아웃</button></header>{page}</>;
}
