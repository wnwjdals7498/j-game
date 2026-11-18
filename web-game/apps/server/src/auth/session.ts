import type { FastifyReply, FastifyRequest } from 'fastify';
import type { UserView } from '@jgame/protocol';

export const SESSION_COOKIE = 'sid';
export const SESSION_TTL_SECONDS = 7 * 24 * 60 * 60;

export function requireUser(request: FastifyRequest, reply: FastifyReply): UserView | undefined {
  if (!request.user) {
    void reply.code(401).send({ code: 'unauthorized' });
    return undefined;
  }
  return request.user;
}

declare module 'fastify' {
  interface FastifyRequest { user: UserView | null }
}
