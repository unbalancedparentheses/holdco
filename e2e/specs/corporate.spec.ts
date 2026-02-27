import { test, expect } from '@playwright/test';

test.describe('Org Chart (/org-chart)', () => {
  test('loads and displays page title', async ({ page }) => {
    await page.goto('/org-chart');
    await expect(page.locator('h1')).toContainText('Org Chart');
    await expect(page.locator('.deck')).toContainText(
      'Corporate structure and ownership hierarchy'
    );
  });

  test('shows seeded parent company Acme Holdings', async ({ page }) => {
    await page.goto('/org-chart');
    await expect(page.locator('body')).toContainText('Acme Holdings');
  });

  test('shows child companies under Acme Holdings', async ({ page }) => {
    await page.goto('/org-chart');
    const body = page.locator('body');
    await expect(body).toContainText('Acme Tech');
    await expect(body).toContainText('Acme Capital');
    await expect(body).toContainText('Acme Media');
    await expect(body).toContainText('Acme Retail');
  });

  test('displays ownership percentages', async ({ page }) => {
    await page.goto('/org-chart');
    // Child companies should show ownership percentage
    await expect(page.locator('body')).toContainText('% owned');
  });

  test('displays status tags for entities', async ({ page }) => {
    await page.goto('/org-chart');
    // At least one entity should have an active status tag
    await expect(page.locator('.tag-jade').first()).toBeVisible();
  });

  test('shows legend section', async ({ page }) => {
    await page.goto('/org-chart');
    await expect(page.locator('h2').filter({ hasText: 'Legend' })).toBeVisible();
    await expect(page.locator('body')).toContainText('Active entity');
  });

  test('company names link to company show page', async ({ page }) => {
    await page.goto('/org-chart');
    const companyLink = page.locator('a', { hasText: 'Acme Holdings' }).first();
    await expect(companyLink).toBeVisible();
    await companyLink.click();
    await page.waitForURL(/\/companies\/\d+/);
    await expect(page.locator('body')).toContainText('Acme Holdings');
  });

  test('has link to list view', async ({ page }) => {
    await page.goto('/org-chart');
    const listViewLink = page.locator('a', { hasText: 'List View' });
    await expect(listViewLink).toBeVisible();
    await listViewLink.click();
    await page.waitForURL('/companies');
    await expect(page.locator('body')).toContainText('Companies');
  });
});

test.describe('Entity Comparison (/compare)', () => {
  test('loads and displays page title', async ({ page }) => {
    await page.goto('/compare');
    await expect(page.locator('h1')).toContainText('Entity Comparison');
    await expect(page.locator('.deck')).toContainText(
      'Compare balance sheets and income statements side-by-side'
    );
  });

  test('shows entity selection buttons for seeded companies', async ({ page }) => {
    await page.goto('/compare');
    const body = page.locator('body');
    await expect(body).toContainText('Acme Holdings');
    await expect(body).toContainText('Acme Tech');
    await expect(body).toContainText('Acme Capital');
  });

  test('shows empty state when fewer than 2 entities selected', async ({ page }) => {
    await page.goto('/compare');
    await expect(page.locator('.empty-state')).toContainText(
      'Select at least 2 entities'
    );
  });

  test('select two companies and see comparison tables', async ({ page }) => {
    await page.goto('/compare');

    // Click two company buttons to select them
    await page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Holdings' }).click();
    await page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Tech' }).click();

    // Empty state should disappear and comparison data should appear
    await expect(page.locator('.empty-state')).not.toBeVisible();

    // Selected tags should be shown
    await expect(page.locator('body')).toContainText('Selected:');

    // Balance Sheet tab should be active by default with Assets, Liabilities, Equity sections
    await expect(page.locator('body')).toContainText('Total Assets');
    await expect(page.locator('body')).toContainText('Total Liabilities');
    await expect(page.locator('body')).toContainText('Total Equity');
  });

  test('switch to income statement tab', async ({ page }) => {
    await page.goto('/compare');

    // Select two companies
    await page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Holdings' }).click();
    await page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Tech' }).click();

    // Switch to Income Statement tab
    await page.locator('button[phx-click="switch_tab"][phx-value-tab="income_statement"]').click();

    // Income statement sections should appear
    await expect(page.locator('body')).toContainText('Total Revenue');
    await expect(page.locator('body')).toContainText('Total Expenses');
    await expect(page.locator('body')).toContainText('Net Income');
  });

  test('remove a selected company', async ({ page }) => {
    await page.goto('/compare');

    // Select two companies
    await page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Holdings' }).click();
    await page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Tech' }).click();

    // Comparison tables should be visible
    await expect(page.locator('body')).toContainText('Total Assets');

    // Remove one company using the x button in the selected tags
    await page.locator('button[phx-click="remove_company"]').first().click();

    // With only one company selected, empty state should return
    await expect(page.locator('.empty-state')).toContainText(
      'Select at least 2 entities'
    );
  });

  test('maximum 4 entities can be selected', async ({ page }) => {
    await page.goto('/compare');

    // Select 4 companies
    const buttons = page.locator('button[phx-click="toggle_company"]');
    const count = await buttons.count();

    for (let i = 0; i < Math.min(count, 4); i++) {
      await buttons.nth(i).click();
    }

    // Should show the maximum message if 4 were selected
    if (count >= 4) {
      await expect(page.locator('body')).toContainText('Maximum 4 entities selected');
    }
  });

  test('toggle company deselects when clicked again', async ({ page }) => {
    await page.goto('/compare');

    const holdingsBtn = page.locator('button[phx-click="toggle_company"]', { hasText: 'Acme Holdings' });

    // Select
    await holdingsBtn.click();
    await expect(holdingsBtn).toHaveClass(/btn-primary/);

    // Deselect
    await holdingsBtn.click();
    await expect(holdingsBtn).toHaveClass(/btn-secondary/);
  });
});
