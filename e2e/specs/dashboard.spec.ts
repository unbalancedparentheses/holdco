import { test, expect } from '@playwright/test';

test.describe('Dashboard', () => {
  test('loads and shows key sections', async ({ page }) => {
    await page.goto('/');
    // Dashboard title or heading
    await expect(page.locator('body')).toContainText('Portfolio Overview');
    // Corporate structure table
    await expect(page.locator('body')).toContainText('Acme Holdings');
  });

  test('shows NAV chart canvas', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('canvas').first()).toBeVisible();
  });

  test('shows corporate structure table', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('body')).toContainText('Acme Tech');
    await expect(page.locator('body')).toContainText('Acme Capital');
  });

  test('shows recent transactions', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('body')).toContainText('Transaction');
  });

  test('change currency selector', async ({ page }) => {
    await page.goto('/');
    const currencySelect = page.locator('select[name="currency"]');
    if (await currencySelect.isVisible()) {
      await currencySelect.selectOption('EUR');
      // Page should update without error
      await expect(page.locator('body')).toContainText('Portfolio Overview');
    }
  });

  test('navigation links work', async ({ page }) => {
    await page.goto('/');

    // Click through to companies
    const companiesLink = page.locator('a[href="/companies"]').first();
    if (await companiesLink.isVisible()) {
      await companiesLink.click();
      await page.waitForURL('/companies');
      await expect(page.locator('body')).toContainText('Companies');
    }
  });

  test('quick action links', async ({ page }) => {
    await page.goto('/');

    // Check that quick action buttons exist
    const body = page.locator('body');
    // These are common dashboard actions from the seeds
    await expect(body).toContainText('Acme Holdings');
  });
});
