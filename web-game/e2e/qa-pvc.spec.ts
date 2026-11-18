import { expect, test } from '@playwright/test';

test('qa user plays omok against the computer to the end', async ({ page }) => {
  await page.goto('/#/login');
  await page.getByLabel('닉네임').fill('e2e');
  await page.getByRole('button', { name: 'QA 로그인' }).click();
  await page.getByRole('link', { name: '오목', exact: true }).click();
  await page.getByLabel('색').selectOption('0');
  await page.getByLabel('컴퓨터 수준').selectOption('random');
  await page.getByRole('button', { name: '컴퓨터와 두기' }).click();

  const result = page.locator('main section h2');
  for (let move = 0; move < 113; move++) {
    await expect(page.getByText('내 차례', { exact: true }).or(result)).toBeVisible();
    if (await result.isVisible()) break;
    const cell = page.locator('[data-cell][data-stone=""]').first();
    const position = await cell.getAttribute('data-cell');
    await cell.click();
    await expect(page.locator(`[data-cell="${position}"]`)).toHaveAttribute('data-stone', '0');
  }
  await expect(result).toHaveText(/^(승리|패배|무승부)$/);
  const outcome = await result.textContent();
  const gameHash = new URL(page.url()).hash;
  await page.getByRole('link', { name: '내 기록' }).click();
  const entries = page.locator('main li');
  await expect(entries).toHaveCount(1);
  await expect(entries.first().locator('a')).toHaveAttribute('href', gameHash);
  await expect(entries.first()).toContainText(outcome!);
});
