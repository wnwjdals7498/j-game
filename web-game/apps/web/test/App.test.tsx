import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, expect, test, vi } from 'vitest';
import { App } from '../src/App';

afterEach(() => { cleanup(); vi.unstubAllGlobals(); });
test('header labels QA accounts only', async () => {
  const fetcher = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ user: { id: 1, name: '사용자', isQa: true, provider: 'qa' } }) });
  vi.stubGlobal('fetch', fetcher);
  const { unmount } = render(<App />);
  expect(await screen.findByText('QA')).toBeTruthy();
  unmount();
  fetcher.mockResolvedValue({ ok: true, json: async () => ({ user: { id: 2, name: '일반 사용자', isQa: false, provider: 'google' } }) });
  render(<App />);
  await screen.findByText('일반 사용자');
  expect(screen.queryByText('QA')).toBeNull();
});
