import type { FastifyInstance } from 'fastify';
import { loadConfig, type Config } from '../src/config.js';

export function testConfig(over: Partial<Config> = {}): Config {
  return { ...loadConfig({}), dbPath: ':memory:', botDelayMs: 0, qaLogin: true, ...over };
}

export async function qaLogin(app: FastifyInstance, name: string): Promise<string> {
  const response = await app.inject({ method: 'POST', url: '/api/auth/qa', payload: { name } });
  const cookie = response.cookies.find((item) => item.name === 'sid');
  if (response.statusCode !== 200 || !cookie) throw new Error('QA login failed');
  return `${cookie.name}=${cookie.value}`;
}
