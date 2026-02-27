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

// ---------------------------------------------------------------------------
// 3. KPI Tracking  (/kpis)
// ---------------------------------------------------------------------------
test.describe('KPI Tracking', () => {
  test('page loads and displays KPI tracking', async ({ page }) => {
    await page.goto('/kpis');
    await expect(page.locator('h1')).toContainText('KPI Tracking');
    await expect(page.locator('.deck')).toContainText(
      'Monitor key performance indicators'
    );

    // Metrics strip
    await expect(page.locator('.metric-label').filter({ hasText: 'Total KPIs' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'On Target' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Warning' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Below Threshold' })).toBeVisible();
  });

  test('create a new KPI with all fields', async ({ page }) => {
    await page.goto('/kpis');

    await page.locator('[phx-click="show_form"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="kpi[name]"]', 'E2E Revenue Growth');
    await page.locator('select[name="kpi[metric_type]"]').selectOption('percentage');
    await page.fill('input[name="kpi[target_value]"]', '15');
    await page.fill('input[name="kpi[threshold_value]"]', '10');
    await page.fill('input[name="kpi[unit]"]', '%');
    await page.locator('select[name="kpi[company_id]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('KPI created');
    await expect(page.locator('body')).toContainText('E2E Revenue Growth');
  });

  test('select a KPI to view detail', async ({ page }) => {
    await page.goto('/kpis');

    // Click on the first KPI name link to select it
    await page.locator('[phx-click="select_kpi"]').first().click();

    // The detail panel should now show the KPI name with "Snapshots"
    await expect(page.locator('h2').filter({ hasText: 'Snapshots' })).toBeVisible();

    // Detail metrics should appear
    await expect(page.locator('.metric-label').filter({ hasText: 'Current Value' })).toBeVisible();
    await expect(page.locator('.metric-label', { hasText: /^Target$/ })).toBeVisible();
    await expect(page.locator('.metric-label', { hasText: /^Threshold$/ })).toBeVisible();

    // "Close Detail" button should be visible
    await expect(page.locator('[phx-click="deselect_kpi"]')).toBeVisible();
  });

  test('record a snapshot for a KPI', async ({ page }) => {
    await page.goto('/kpis');

    // First, ensure at least one KPI exists by creating one
    await page.locator('[phx-click="show_form"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="kpi[name]"]', 'E2E Snapshot KPI');
    await page.locator('select[name="kpi[metric_type]"]').selectOption('count');
    await page.fill('input[name="kpi[target_value]"]', '100');
    await page.fill('input[name="kpi[threshold_value]"]', '80');
    await page.fill('input[name="kpi[unit]"]', 'users');
    await page.locator('select[name="kpi[company_id]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('KPI created');

    // Select the KPI we just created
    const kpiLink = page.locator('[phx-click="select_kpi"]', { hasText: 'E2E Snapshot KPI' }).first();
    await kpiLink.click();
    await expect(page.locator('h2').filter({ hasText: 'E2E Snapshot KPI' })).toBeVisible();

    // Click "Record Snapshot"
    await page.locator('[phx-click="show_snapshot_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Fill snapshot form
    await page.fill('input[name="snapshot[date]"]', '2026-02-15');
    await page.fill('input[name="snapshot[current_value]"]', '85');
    await page.fill('textarea[name="snapshot[notes]"]', 'E2E snapshot test note');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Snapshot recorded');
  });

  test('edit a KPI', async ({ page }) => {
    await page.goto('/kpis');

    // Click the first edit button
    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();
    await expect(page.locator('.dialog-header')).toContainText('Edit KPI');

    // Update the name
    await page.fill('input[name="kpi[name]"]', 'E2E Updated KPI Name');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('KPI updated');
    await expect(page.locator('body')).toContainText('E2E Updated KPI Name');
  });

  test('delete a KPI', async ({ page }) => {
    await page.goto('/kpis');

    // First create a KPI to safely delete
    await page.locator('[phx-click="show_form"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="kpi[name]"]', 'E2E Delete Me KPI');
    await page.locator('select[name="kpi[metric_type]"]').selectOption('ratio');
    await page.fill('input[name="kpi[target_value]"]', '5');
    await page.fill('input[name="kpi[threshold_value]"]', '3');
    await page.fill('input[name="kpi[unit]"]', 'x');
    await page.locator('select[name="kpi[company_id]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('KPI created');
    await expect(page.locator('body')).toContainText('E2E Delete Me KPI');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());

    const row = page.locator('tr', { hasText: 'E2E Delete Me KPI' });
    await row.locator('[phx-click="delete"]').click();
    await expect(page.locator('body')).toContainText('KPI deleted');
    await expect(page.locator('body')).not.toContainText('E2E Delete Me KPI');
  });

  test('filter KPIs by company', async ({ page }) => {
    await page.goto('/kpis');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    // Select first real company
    await companySelect.selectOption({ index: 1 });

    // Page should still render without error
    await expect(page.locator('h1')).toContainText('KPI Tracking');

    // Reset to all companies
    await companySelect.selectOption('');
    await expect(page.locator('h1')).toContainText('KPI Tracking');
  });

  test('deselect KPI closes detail panel', async ({ page }) => {
    await page.goto('/kpis');

    // Select a KPI
    await page.locator('[phx-click="select_kpi"]').first().click();
    await expect(page.locator('h2').filter({ hasText: 'Snapshots' })).toBeVisible();

    // Deselect
    await page.locator('[phx-click="deselect_kpi"]').click();

    // Detail panel should show the placeholder text
    await expect(page.locator('body')).toContainText(
      'Select a KPI from the list to view its historical snapshots'
    );
  });
});
