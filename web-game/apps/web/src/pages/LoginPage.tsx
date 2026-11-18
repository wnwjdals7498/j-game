import { useEffect, useRef, useState } from 'react';
import type { ProviderInfo, UserView } from '@jgame/protocol';
import { api } from '../api';

type GoogleApi = { accounts: { id: { initialize: (options: { client_id: string; callback: (response: { credential: string }) => void }) => void; renderButton: (element: HTMLElement, options: object) => void } } };
declare global { interface Window { google?: GoogleApi } }

function GoogleButton({ clientId, onLogin, onError }: { clientId: string; onLogin: (user: UserView) => void; onError: (message: string) => void }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let active = true;
    const initialize = () => {
      if (!active || !window.google || !ref.current) return;
      window.google.accounts.id.initialize({ client_id: clientId, callback: ({ credential }) => { void api<{ user: UserView }>('/api/auth/google', { credential }).then(({ user }) => onLogin(user)).catch(() => onError('로그인에 실패했습니다.')); } });
      window.google.accounts.id.renderButton(ref.current, { theme: 'outline', size: 'large' });
    };
    if (window.google) initialize();
    else {
      const script = document.createElement('script'); script.src = 'https://accounts.google.com/gsi/client'; script.async = true; script.onload = initialize; script.onerror = () => onError('구글 로그인을 불러오지 못했습니다.'); document.head.appendChild(script);
      return () => { active = false; script.remove(); };
    }
    return () => { active = false; };
  }, [clientId, onLogin, onError]);
  return <div data-google-button ref={ref} />;
}
export function LoginPage({ onLogin }: { onLogin: (user: UserView) => void }) {
  const [providers, setProviders] = useState<ProviderInfo[]>([]);
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  useEffect(() => { let active = true; void api<{ providers: ProviderInfo[] }>('/api/auth/providers').then(data => { if (active) setProviders(data.providers); }).catch(() => { if (active) setError('로그인 방법을 불러오지 못했습니다.'); }); return () => { active = false; }; }, []);
  return <main><h1>로그인</h1><div className="stack">{providers.map(provider => provider.kind === 'qa' ? <form key={provider.id} onSubmit={event => { event.preventDefault(); void api<{ user: UserView }>('/api/auth/qa', { name }).then(({ user }) => onLogin(user)).catch(() => setError('로그인에 실패했습니다.')); }}><label>닉네임 <input value={name} onChange={event => setName(event.target.value)} maxLength={20} required /></label><button type="submit">QA 로그인</button></form> : provider.kind === 'redirect' ? <a className="button" key={provider.id} href={provider.startUrl}>{provider.id} 로그인</a> : <GoogleButton key={provider.id} clientId={provider.clientId} onLogin={onLogin} onError={setError} />)}</div>{error && <p role="alert">{error}</p>}</main>;
}
