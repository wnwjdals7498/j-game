import { createHash, randomBytes } from 'node:crypto';

export type OAuthProvider = 'kakao' | 'naver' | 'github';
type PendingAuth = { provider: string; verifier: string | null };

export class PendingAuthStore {
  private readonly entries = new Map<string, PendingAuth & { createdAt: number }>();

  put(state: string, value: PendingAuth): void {
    this.entries.set(state, { ...value, createdAt: Date.now() });
  }

  take(state: string, now: number): PendingAuth | undefined {
    const entry = this.entries.get(state);
    this.entries.delete(state);
    if (!entry || now - entry.createdAt >= 600_000) return undefined;
    return { provider: entry.provider, verifier: entry.verifier };
  }
}

function object(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' ? value as Record<string, unknown> : {};
}

export function mapProfile(provider: OAuthProvider, json: unknown): { providerUserId: string; displayName: string } {
  const root = object(json);
  const profile = provider === 'naver' ? object(root.response) : root;
  const id = profile.id;
  if ((typeof id !== 'string' && typeof id !== 'number') || String(id).trim() === '') throw new Error('Invalid provider user ID');
  const name = provider === 'kakao' ? object(object(root.kakao_account).profile).nickname : provider === 'naver' ? profile.nickname : profile.name ?? profile.login;
  return { providerUserId: String(id), displayName: typeof name === 'string' && name.trim() ? name : `${provider} 사용자` };
}

export function randomToken(): string { return randomBytes(32).toString('base64url'); }
export function challenge(verifier: string): string { return createHash('sha256').update(verifier).digest('base64url'); }
