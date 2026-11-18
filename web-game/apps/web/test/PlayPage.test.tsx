import { act, cleanup, fireEvent, render, renderHook, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, expect, test, vi } from 'vitest';
import { omok } from '@jgame/engine';
import type { GameView, UserView } from '@jgame/protocol';
import { PlayPage } from '../src/pages/PlayPage';
import { useGameSocket } from '../src/useGameSocket';

class FakeWebSocket {
  static OPEN = 1;
  static instances: FakeWebSocket[] = [];
  readyState = 0;
  onopen: (() => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  onclose: (() => void) | null = null;
  send = vi.fn();
  constructor() { FakeWebSocket.instances.push(this); }
  open() { this.readyState = 1; this.onopen?.(); }
  state(game: GameView) { this.onmessage?.({ data: JSON.stringify({ type: 'state', game }) }); }
  close() { this.readyState = 3; this.onclose?.(); }
}
const user: UserView = { id: 1, name: '사용자', isQa: true, provider: 'qa' };
const player = { kind: 'human', userId: 1, name: '사용자', isQa: true } as const;
const game: GameView = { id: 42, gameId: 'omok', mode: 'pvc', status: 'playing', roomCode: null, players: [player, { kind: 'bot', level: 'basic' }], state: omok.initialState(), outcome: { kind: 'ongoing' }, endReason: null, moveCount: 0, online: [true, false] };
beforeEach(() => { FakeWebSocket.instances = []; vi.stubGlobal('WebSocket', FakeWebSocket); location.hash = ''; });
afterEach(() => { cleanup(); vi.unstubAllGlobals(); vi.useRealTimers(); });

test('disconnected game blocks moves and resignation until resubscribed state', () => {
  vi.useFakeTimers();
  const { container } = render(<PlayPage id={42} user={user} />);
  const first = FakeWebSocket.instances[0]!;
  act(() => { first.open(); first.state(game); });
  expect(first.send).toHaveBeenCalledTimes(1);
  act(() => first.close());
  expect(screen.getByText('연결 중…')).toBeTruthy();
  expect((screen.getByRole('button', { name: '기권' }) as HTMLButtonElement).disabled).toBe(true);
  fireEvent.click(container.querySelector('[data-cell="3,4"]')!);
  expect(first.send).toHaveBeenCalledTimes(1);
  act(() => vi.advanceTimersByTime(1000));
  const second = FakeWebSocket.instances[1]!;
  act(() => second.open());
  fireEvent.click(container.querySelector('[data-cell="3,4"]')!);
  expect(second.send).toHaveBeenCalledTimes(1);
  act(() => second.state(game));
  fireEvent.click(container.querySelector('[data-cell="3,4"]')!);
  expect(second.send).toHaveBeenLastCalledWith(JSON.stringify({ type: 'move', gameId: 42, move: { x: 3, y: 4 } }));
});

test('sending while socket is not open reports failure', () => {
  const { result } = renderHook(() => useGameSocket(42));
  act(() => result.current.send({ type: 'resign', gameId: 42 }));
  expect(result.current.error).toBe('disconnected');
});

test('rematch creates a pvc game with the same seat and bot level', async () => {
  const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ game: { id: 99 } }) });
  vi.stubGlobal('fetch', fetcher);
  const finished: GameView = { ...game, status: 'finished', players: [{ kind: 'bot', level: 'random' }, player], outcome: { kind: 'win', winner: 1 } };
  render(<PlayPage id={42} user={user} />);
  act(() => { const socket = FakeWebSocket.instances[0]!; socket.open(); socket.state(finished); });
  fireEvent.click(screen.getByRole('button', { name: '다시 하기' }));
  await waitFor(() => expect(location.hash).toBe('#/play/99'));
  expect(fetcher).toHaveBeenCalledWith('/api/games/pvc', expect.objectContaining({ method: 'POST', body: JSON.stringify({ gameId: 'omok', seat: 1, botLevel: 'random' }) }));
  expect(screen.getByRole('link', { name: '로비로' }).getAttribute('href')).toBe('#/lobby/omok');
});

test('rematch creates a pvp room with the same seat', async () => {
  const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ game: { id: 100 } }) });
  vi.stubGlobal('fetch', fetcher);
  const finished: GameView = { ...game, mode: 'pvp', status: 'finished', players: [player, { kind: 'human', userId: 2, name: '상대', isQa: true }], outcome: { kind: 'draw' } };
  render(<PlayPage id={42} user={user} />);
  act(() => { const socket = FakeWebSocket.instances[0]!; socket.open(); socket.state(finished); });
  fireEvent.click(screen.getByRole('button', { name: '다시 하기' }));
  await waitFor(() => expect(location.hash).toBe('#/play/100'));
  expect(fetcher).toHaveBeenCalledWith('/api/rooms', expect.objectContaining({ method: 'POST', body: JSON.stringify({ gameId: 'omok', seat: 0 }) }));
});

test('rematch failure is shown and can be retried', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network')));
  const finished: GameView = { ...game, status: 'finished', outcome: { kind: 'draw' } };
  render(<PlayPage id={42} user={user} />);
  act(() => { const socket = FakeWebSocket.instances[0]!; socket.open(); socket.state(finished); });
  fireEvent.click(screen.getByRole('button', { name: '다시 하기' }));
  await screen.findByRole('alert');
  expect(screen.getByRole('alert').textContent).toBe('새 대국을 만들지 못했습니다.');
  expect((screen.getByRole('button', { name: '다시 하기' }) as HTMLButtonElement).disabled).toBe(false);
});
