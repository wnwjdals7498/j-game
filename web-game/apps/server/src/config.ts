import { resolve } from 'node:path';

export interface OAuthProviderConfig { clientId: string; clientSecret?: string; authorizeUrl: string; tokenUrl: string; userUrl: string; pkce: boolean; scope?: string }
export interface Config { port: number; host: string; dbPath: string; qaLogin: boolean; publicOrigin: string; botDelayMs: number; webDist: string | null; google: { clientId: string; jwksUrl: string; issuers: string[] } | null; oauth: Partial<Record<'kakao' | 'naver' | 'github', OAuthProviderConfig>> }

export function loadConfig(env: Record<string, string | undefined>): Config {
  const oauth: Config['oauth'] = {};
  if (env.KAKAO_CLIENT_ID) oauth.kakao = { clientId: env.KAKAO_CLIENT_ID, clientSecret: env.KAKAO_CLIENT_SECRET, authorizeUrl: 'https://kauth.kakao.com/oauth/authorize', tokenUrl: 'https://kauth.kakao.com/oauth/token', userUrl: 'https://kapi.kakao.com/v2/user/me', pkce: false };
  if (env.NAVER_CLIENT_ID) oauth.naver = { clientId: env.NAVER_CLIENT_ID, clientSecret: env.NAVER_CLIENT_SECRET, authorizeUrl: 'https://nid.naver.com/oauth2.0/authorize', tokenUrl: 'https://nid.naver.com/oauth2.0/token', userUrl: 'https://openapi.naver.com/v1/nid/me', pkce: false };
  if (env.GITHUB_CLIENT_ID) oauth.github = { clientId: env.GITHUB_CLIENT_ID, clientSecret: env.GITHUB_CLIENT_SECRET, authorizeUrl: 'https://github.com/login/oauth/authorize', tokenUrl: 'https://github.com/login/oauth/access_token', userUrl: 'https://api.github.com/user', pkce: true };
  return { port: Number(env.PORT ?? 8840), host: env.HOST ?? '0.0.0.0', dbPath: env.DB_PATH ?? 'data/web-game.sqlite', qaLogin: env.QA_LOGIN === '1', publicOrigin: env.PUBLIC_ORIGIN ?? 'http://localhost:8840', botDelayMs: Number(env.BOT_DELAY_MS ?? 300), webDist: env.WEB_DIST ?? resolve('apps/web/dist'), google: env.GOOGLE_CLIENT_ID ? { clientId: env.GOOGLE_CLIENT_ID, jwksUrl: 'https://www.googleapis.com/oauth2/v3/certs', issuers: ['accounts.google.com', 'https://accounts.google.com'] } : null, oauth };
}
