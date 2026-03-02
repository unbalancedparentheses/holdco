import { test, expect } from '@playwright/test';

// ---------------------------------------------------------------------------
// 1. Reports  (/reports)
// ---------------------------------------------------------------------------
test.describe('Reports', () => {
  test('page loads and displays report cards', async ({ page }) => {
    await page.goto('/reports');
    await expect(page.locator('h1')).toContainText('Reports');
    await expect(page.locator('.deck')).toContainText(
      'Generate printable reports'
    );

    // Verify the report card headings are present
    await expect(page.locator('body')).toContainText('Portfolio NAV Report');
    await expect(page.locator('body')).toContainText('Financial Summary Report');
    await expect(page.locator('body')).toContainText('Compliance Status Report');
    await expect(page.locator('body')).toContainText('Scenarios');
    await expect(page.locator('body')).toContainText('Management Reports');
    await expect(page.locator('body')).toContainText('Audit Package');
  });

  test('report generation links are present', async ({ page }) => {
    await page.goto('/reports');

    // Portfolio NAV report link
    const portfolioLink = page.locator('a[href="/reports/portfolio"]');
    await expect(portfolioLink).toBeVisible();

    // Financial Summary report link
    const financialLink = page.locator('a[href="/reports/financial"]');
    await expect(financialLink).toBeVisible();

    // Compliance Status report link
    const complianceLink = page.locator('a[href="/reports/compliance"]');
    await expect(complianceLink).toBeVisible();

    // Audit Package download link
    const auditLink = page.locator('a[href="/export/audit-package.zip"]');
    await expect(auditLink).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 2. Management Reports  (/management-reports)
// ---------------------------------------------------------------------------
test.describe('Management Reports', () => {
  test('page loads and displays templates section', async ({ page }) => {
    await page.goto('/management-reports');
    await expect(page.locator('h1')).toContainText('Management Reports');
    await expect(page.locator('.deck')).toContainText(
      'Build custom report templates'
    );

    // Metrics strip
    await expect(page.locator('.metric-label').filter({ hasText: 'Saved Templates' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Available Sections' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Companies' })).toBeVisible();
  });

  test('shows report templates table', async ({ page }) => {
    await page.goto('/management-reports');

    await expect(page.locator('h2').filter({ hasText: 'Report Templates' })).toBeVisible();
    await expect(page.locator('table').first()).toBeVisible();
  });
});

