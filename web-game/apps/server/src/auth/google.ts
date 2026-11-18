import { createRemoteJWKSet, jwtVerify } from 'jose';

export function createGoogleVerifier(cfg: { clientId: string; jwksUrl: string; issuers: string[] }): (credential: string) => Promise<{ providerUserId: string; displayName: string }> {
  const jwks = createRemoteJWKSet(new URL(cfg.jwksUrl));
  return async (credential) => {
    const { payload } = await jwtVerify(credential, jwks, { issuer: cfg.issuers, audience: cfg.clientId, algorithms: ['RS256'], requiredClaims: ['sub', 'exp'] });
    if (!payload.sub || (payload.name != null && typeof payload.name !== 'string') || (payload.email != null && typeof payload.email !== 'string')) throw new Error('Invalid Google profile');
    return { providerUserId: payload.sub, displayName: (payload.name as string | undefined | null) ?? (payload.email as string | undefined | null) ?? 'Google 사용자' };
  };
}
