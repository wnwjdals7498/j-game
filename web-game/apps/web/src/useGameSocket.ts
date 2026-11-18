import { useCallback, useEffect, useRef, useState } from 'react';
import type { ClientMessage, ErrorCode, GameView, ServerMessage } from '@jgame/protocol';
export function useGameSocket(gameId: number): { game: GameView | null; error: ErrorCode | 'disconnected' | null; connected: boolean; send: (m: ClientMessage) => void } {
  const [game, setGame] = useState<GameView | null>(null);
  const [error, setError] = useState<ErrorCode | 'disconnected' | null>(null);
  const [connected, setConnected] = useState(false);
  const ready = useRef(false);
  const socket = useRef<WebSocket | null>(null);
  useEffect(() => {
    let stopped = false; let timer: ReturnType<typeof setTimeout> | undefined;
    ready.current = false;
    setConnected(false);
    setGame(null);
    const connect = () => {
      const ws = new WebSocket(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws`); socket.current = ws;
      ws.onopen = () => { ws.send(JSON.stringify({ type: 'subscribe', gameId })); };
      ws.onmessage = event => { if (stopped) return; const message = JSON.parse(String(event.data)) as ServerMessage; if (message.type === 'state') { ready.current = true; setGame(message.game); setConnected(true); setError(null); } else setError(message.code); };
      ws.onclose = () => { if (stopped) return; ready.current = false; setConnected(false); timer = setTimeout(connect, 1000); };
    };
    connect(); return () => { stopped = true; ready.current = false; if (timer) clearTimeout(timer); socket.current?.close(); socket.current = null; };
  }, [gameId]);
  const send = useCallback((message: ClientMessage) => {
    if (socket.current?.readyState === WebSocket.OPEN && ready.current) socket.current.send(JSON.stringify(message));
    else setError('disconnected');
  }, []);
  return { game, error, connected, send };
}
