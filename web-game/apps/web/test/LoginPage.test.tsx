import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, expect, test, vi } from 'vitest';
import { LoginPage } from '../src/pages/LoginPage';
afterEach(() => { cleanup(); vi.unstubAllGlobals(); });
test('login page shows only qa form when providers are [qa]', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => ({ providers: [{ id: 'qa', kind: 'qa' }] }) }));
  render(<LoginPage onLogin={vi.fn()} />);
  expect(await screen.findByLabelText('닉네임')).toBeTruthy();
  expect(screen.getByRole('button', { name: 'QA 로그인' })).toBeTruthy();
  expect(document.querySelector('[data-google-button]')).toBeNull();
});
test('login page shows redirect links for kakao, naver, github', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, json: async () => ({ providers: ['kakao', 'naver', 'github'].map(id => ({ id, kind: 'redirect', startUrl: `/auth/${id}/start` })) }) }));
  render(<LoginPage onLogin={vi.fn()} />);
  for (const id of ['kakao', 'naver', 'github']) expect((await screen.findByRole('link', { name: new RegExp(id, 'i') })).getAttribute('href')).toBe(`/auth/${id}/start`);
});
