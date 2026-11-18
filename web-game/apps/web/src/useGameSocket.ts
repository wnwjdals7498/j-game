import { useCallback, useEffect, useRef, useState } from 'react';
import type { ClientMessage, ErrorCode, GameView, ServerMessage } from '@jgame/protocol';
export function useGameSocket(gameId: number): { game: GameView | null; error: ErrorCode | null; send: (m: ClientMessage) => void } {
  const [game, setGame] = useState<GameView | null>(null);
  const [error, setError] = useState<ErrorCode | null>(null);
  const socket = useRef<WebSocket | null>(null);
  useEffect(() => {
    let stopped = false; let timer: ReturnType<typeof setTimeout> | undefined;
    const connect = () => {
      const ws = new WebSocket(`${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws`); socket.current = ws;
      ws.onopen = () => { ws.send(JSON.stringify({ type: 'subscribe', gameId })); };
      ws.onmessage = event => { const message = JSON.parse(String(event.data)) as ServerMessage; if (message.type === 'state') { setGame(message.game); setError(null); } else setError(message.code); };
      ws.onclose = () => { if (!stopped) timer = setTimeout(connect, 1000); };
    };
    connect(); return () => { stopped = true; if (timer) clearTimeout(timer); socket.current?.close(); socket.current = null; };
  }, [gameId]);
  const send = useCallback((message: ClientMessage) => { if (socket.current?.readyState === WebSocket.OPEN) socket.current.send(JSON.stringify(message)); }, []);
  return { game, error, send };
}
