import { expect, test } from 'vitest';
import { loadConfig } from '../src/config.js';

test('loadConfig defaults', () => {
  const c = loadConfig({});
  expect(c).toMatchObject({ port: 8840, host: '0.0.0.0', qaLogin: false, publicOrigin: 'http://localhost:8840', botDelayMs: 300, google: null, oauth: {} });
  expect(c.webDist).toBe(`${process.cwd()}/apps/web/dist`);
});

test('provider enabled only when its client id is set', () => {
  const c = loadConfig({ QA_LOGIN: '1', GOOGLE_CLIENT_ID: 'g', GITHUB_CLIENT_ID: 'h', GITHUB_CLIENT_SECRET: 's' });
  expect(c.qaLogin).toBe(true);
  expect(c.google?.jwksUrl).toBe('https://www.googleapis.com/oauth2/v3/certs');
  expect(Object.keys(c.oauth)).toEqual(['github']);
  expect(c.oauth.github).toMatchObject({ pkce: true, tokenUrl: 'https://github.com/login/oauth/access_token' });
});
