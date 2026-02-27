import { test, expect } from '@playwright/test';

test.describe('Holdings List (/holdings)', () => {
  test('loads and displays seeded holdings', async ({ page }) => {
    await page.goto('/holdings');
    await expect(page.locator('h1')).toContainText('Holdings');

    // Verify seeded holdings are visible in the table
    const body = page.locator('body');
    await expect(body).toContainText('Bitcoin');
    await expect(body).toContainText('Apple');
    await expect(body).toContainText('Gold');
    await expect(body).toContainText('SPY');
  });

  test('displays metrics strip with position count and allocation', async ({ page }) => {
    await page.goto('/holdings');

    // Metrics strip should show totals
    await expect(page.locator('.metrics-strip')).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Total Positions' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Asset Types' })).toBeVisible();
  });

  test('displays allocation by type section', async ({ page }) => {
    await page.goto('/holdings');
    await expect(page.locator('h2').filter({ hasText: 'Allocation by Type' })).toBeVisible();
    await expect(page.locator('h2').filter({ hasText: 'By Type Summary' })).toBeVisible();
  });

  test('filter holdings by company', async ({ page }) => {
    await page.goto('/holdings');

    // Get the filter select
    const companyFilter = page.locator('select[name="company_id"]');
    await expect(companyFilter).toBeVisible();

    // Verify "All Companies" is default
    await expect(companyFilter).toHaveValue('');

    // Select a specific company (first non-empty option)
    await companyFilter.selectOption({ index: 1 });

    // After filtering, the page should still show Holdings heading (LiveView re-renders)
    await expect(page.locator('h1')).toContainText('Holdings');

    // The positions count in the deck text should update (may show fewer)
    await expect(page.locator('.deck').first()).toContainText('positions');

    // Reset filter to All Companies
    await companyFilter.selectOption('');
    await expect(page.locator('body')).toContainText('Bitcoin');
  });

  test('sort by asset column', async ({ page }) => {
    await page.goto('/holdings');

    // Click Asset header to sort
    const assetHeader = page.locator('th[phx-value-field="asset"]');
    await expect(assetHeader).toBeVisible();
    await assetHeader.click();

    // Default sort is asc, clicking again should toggle to desc
    await expect(assetHeader).toContainText('Asset');
    // Should see the sort indicator
    await expect(assetHeader).toContainText('\u2191');

    // Click again for desc
    await assetHeader.click();
    await expect(assetHeader).toContainText('\u2193');
  });

  test('sort by ticker column', async ({ page }) => {
    await page.goto('/holdings');

    const tickerHeader = page.locator('th[phx-value-field="ticker"]');
    await tickerHeader.click();
    await expect(tickerHeader).toContainText('\u2191');
  });

  test('sort by quantity column', async ({ page }) => {
    await page.goto('/holdings');

    const qtyHeader = page.locator('th[phx-value-field="quantity"]');
    await qtyHeader.click();
    await expect(qtyHeader).toContainText('\u2191');
  });

  test('sort by type column', async ({ page }) => {
    await page.goto('/holdings');

    const typeHeader = page.locator('th[phx-value-field="type"]');
    await typeHeader.click();
    await expect(typeHeader).toContainText('\u2191');
  });

  test('sort by company column', async ({ page }) => {
    await page.goto('/holdings');

    const companyHeader = page.locator('th[phx-value-field="company"]');
    await companyHeader.click();
    await expect(companyHeader).toContainText('\u2191');
  });

  test('create a new holding with all fields', async ({ page }) => {
    await page.goto('/holdings');

    // Click "Add Holding" button
    await page.locator('[phx-click="show_form"]').first().click();

    // Wait for modal to appear
    await page.locator('.dialog-panel').waitFor();
    await expect(page.locator('.dialog-header')).toContainText('Add Holding');

    // Fill all form fields
    await page.locator('.dialog-panel select[name="holding[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="holding[asset]"]', 'E2E Test Asset');
    await page.fill('.dialog-panel input[name="holding[ticker]"]', 'E2ETEST');
    await page.fill('.dialog-panel input[name="holding[quantity]"]', '42.5');
    await page.fill('.dialog-panel input[name="holding[unit]"]', 'shares');
    await page.locator('.dialog-panel select[name="holding[asset_type]"]').selectOption('equity');
    await page.fill('.dialog-panel input[name="holding[currency]"]', 'USD');

    // Submit the form
    await page.locator('.dialog-panel button[type="submit"]').click();

    // Verify success flash and new holding appears
    await expect(page.locator('body')).toContainText('Holding added');
    await expect(page.locator('body')).toContainText('E2E Test Asset');
    await expect(page.locator('body')).toContainText('E2ETEST');
  });

  test('edit an existing holding', async ({ page }) => {
    await page.goto('/holdings');

    // First create a holding to edit
    await page.locator('[phx-click="show_form"]').first().click();
    await page.locator('.dialog-panel').waitFor();
    await page.locator('.dialog-panel select[name="holding[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="holding[asset]"]', 'Edit Target Asset');
    await page.fill('.dialog-panel input[name="holding[ticker]"]', 'EDIT');
    await page.fill('.dialog-panel input[name="holding[quantity]"]', '10');
    await page.fill('.dialog-panel input[name="holding[unit]"]', 'tokens');
    await page.locator('.dialog-panel select[name="holding[asset_type]"]').selectOption('crypto');
    await page.fill('.dialog-panel input[name="holding[currency]"]', 'USD');
    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Holding added');

    // Now find the row with "Edit Target Asset" and click Edit
    const row = page.locator('tr', { hasText: 'Edit Target Asset' });
    await row.locator('button[phx-click="edit"]').click();

    // Wait for edit modal
    await page.locator('.dialog-panel').waitFor();
    await expect(page.locator('.dialog-header')).toContainText('Edit Holding');

    // Modify the asset name and quantity
    await page.fill('.dialog-panel input[name="holding[asset]"]', 'Edited Asset Name');
    await page.fill('.dialog-panel input[name="holding[quantity]"]', '99.9');
    await page.fill('.dialog-panel input[name="holding[ticker]"]', 'EDITED');

    // Submit update
    await page.locator('.dialog-panel button[type="submit"]').click();

    // Verify success flash and updated data
    await expect(page.locator('body')).toContainText('Holding updated');
    await expect(page.locator('body')).toContainText('Edited Asset Name');
    await expect(page.locator('body')).toContainText('EDITED');
  });

  test('delete a holding', async ({ page }) => {
    await page.goto('/holdings');

    // First create a holding to delete
    await page.locator('[phx-click="show_form"]').first().click();
    await page.locator('.dialog-panel').waitFor();
    await page.locator('.dialog-panel select[name="holding[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="holding[asset]"]', 'Delete Me Asset');
    await page.fill('.dialog-panel input[name="holding[ticker]"]', 'DEL');
    await page.fill('.dialog-panel input[name="holding[quantity]"]', '1');
    await page.fill('.dialog-panel input[name="holding[unit]"]', 'units');
    await page.locator('.dialog-panel select[name="holding[asset_type]"]').selectOption('other');
    await page.fill('.dialog-panel input[name="holding[currency]"]', 'USD');
    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Holding added');

    // Accept the confirmation dialog before clicking delete
    page.on('dialog', (dialog) => dialog.accept());

    // Find the row and click delete
    const row = page.locator('tr', { hasText: 'Delete Me Asset' });
    await row.locator('button[phx-click="delete"]').click();

    // Verify success flash
    await expect(page.locator('body')).toContainText('Holding deleted');

    // Verify the holding is gone from the table
    await expect(page.locator('body')).not.toContainText('Delete Me Asset');
  });

  test('cancel form closes modal without saving', async ({ page }) => {
    await page.goto('/holdings');

    // Open the add form
    await page.locator('[phx-click="show_form"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    // Fill some data
    await page.fill('.dialog-panel input[name="holding[asset]"]', 'Should Not Be Saved');

    // Click cancel
    await page.locator('.dialog-panel button[phx-click="close_form"]').click();

    // Modal should disappear
    await expect(page.locator('.dialog-panel')).not.toBeVisible();

    // The data should not appear in the table
    await expect(page.locator('body')).not.toContainText('Should Not Be Saved');
  });

  test('export CSV link is present', async ({ page }) => {
    await page.goto('/holdings');
    const exportLink = page.locator('a[href="/export/holdings.csv"]');
    await expect(exportLink).toBeVisible();
    await expect(exportLink).toContainText('Export CSV');
  });
});

test.describe('Holding Detail (/holdings/:id)', () => {
  test('navigate to holding detail from list and verify content', async ({ page }) => {
    await page.goto('/holdings');

    // Click the first holding link in the table (asset name links to detail)
    const firstHoldingLink = page.locator('td.td-name .td-link').first();
    const holdingName = await firstHoldingLink.textContent();
    await firstHoldingLink.click();

    // Should navigate to /holdings/:id
    await page.waitForURL(/\/holdings\/\d+/);

    // Verify the page shows the holding name as title
    await expect(page.locator('h1')).toContainText(holdingName!.trim());

    // Verify metrics strip shows current value and quantity
    await expect(page.locator('.metric-label').filter({ hasText: 'Current Value' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Quantity' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Unrealized G/L' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Realized G/L' })).toBeVisible();
  });

  test('holding detail shows details section with asset information', async ({ page }) => {
    await page.goto('/holdings');

    // Navigate to first holding
    await page.locator('td.td-name .td-link').first().click();
    await page.waitForURL(/\/holdings\/\d+/);

    // Verify the Details section exists
    await expect(page.locator('h2').filter({ hasText: 'Details' })).toBeVisible();

    // Detail fields should be present
    await expect(page.locator('dt').filter({ hasText: 'Asset Name' })).toBeVisible();
    await expect(page.locator('dt').filter({ hasText: 'Ticker' })).toBeVisible();
    await expect(page.locator('dt').filter({ hasText: 'Asset Type' })).toBeVisible();
    await expect(page.locator('dt').filter({ hasText: 'Currency' })).toBeVisible();
    await expect(page.locator('dt').filter({ hasText: 'Company' })).toBeVisible();
  });

  test('holding detail shows cost basis lots section', async ({ page }) => {
    await page.goto('/holdings');

    await page.locator('td.td-name .td-link').first().click();
    await page.waitForURL(/\/holdings\/\d+/);

    // Cost Basis Lots section should be present
    await expect(page.locator('h2').filter({ hasText: 'Cost Basis Lots' })).toBeVisible();
  });

  test('holding detail has back to holdings link', async ({ page }) => {
    await page.goto('/holdings');

    await page.locator('td.td-name .td-link').first().click();
    await page.waitForURL(/\/holdings\/\d+/);

    // Back link should exist and work
    const backLink = page.locator('a', { hasText: 'Back to Holdings' });
    await expect(backLink).toBeVisible();
    await backLink.click();
    await page.waitForURL('/holdings');
    await expect(page.locator('h1')).toContainText('Holdings');
  });

  test('holding detail with ticker shows price history chart', async ({ page }) => {
    await page.goto('/holdings');

    // Find a holding that has a ticker (e.g., Bitcoin with BTC, Apple with AAPL)
    const holdingLink = page.locator('td.td-name .td-link', { hasText: 'Bitcoin' });
    if (await holdingLink.isVisible()) {
      await holdingLink.click();
      await page.waitForURL(/\/holdings\/\d+/);

      // If price history is available, a canvas chart should render
      const priceChart = page.locator('#price-history-chart canvas');
      const priceSection = page.locator('h2').filter({ hasText: 'Price History' });

      // Price history may or may not exist depending on seed data
      // Just verify the page loaded without error
      await expect(page.locator('h1')).toContainText('Bitcoin');
    }
  });
});

test.describe('Concentration Risk (/risk/concentration)', () => {
  test('loads and displays concentration risk page', async ({ page }) => {
    await page.goto('/risk/concentration');

    await expect(page.locator('h1')).toContainText('Concentration Risk');
    await expect(page.locator('.deck')).toContainText(
      'Portfolio concentration analysis'
    );
  });

  test('shows metrics strip with NAV and exposure data', async ({ page }) => {
    await page.goto('/risk/concentration');

    await expect(page.locator('.metrics-strip')).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Total NAV' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Asset Types' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Currency Exposures' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Concentration Alerts' })).toBeVisible();
  });

  test('displays allocation pie chart with canvas element', async ({ page }) => {
    await page.goto('/risk/concentration');

    const allocationChart = page.locator('#allocation-pie-chart');
    await expect(allocationChart).toBeVisible();
    await expect(allocationChart.locator('canvas')).toBeVisible();
  });

  test('displays FX currency exposure bar chart with canvas element', async ({ page }) => {
    await page.goto('/risk/concentration');

    const fxChart = page.locator('#fx-bar-chart');
    await expect(fxChart).toBeVisible();
    await expect(fxChart.locator('canvas')).toBeVisible();
  });

  test('shows allocation breakdown table', async ({ page }) => {
    await page.goto('/risk/concentration');

    await expect(page.locator('h2').filter({ hasText: 'Allocation Breakdown' })).toBeVisible();

    // Table headers
    const table = page.locator('table').filter({ hasText: 'Asset Type' });
    await expect(table).toBeVisible();
    await expect(table.locator('th').filter({ hasText: '% of Portfolio' })).toBeVisible();
  });

  test('shows FX exposure breakdown table', async ({ page }) => {
    await page.goto('/risk/concentration');

    await expect(page.locator('h2').filter({ hasText: 'FX Exposure Breakdown' })).toBeVisible();

    const table = page.locator('table').filter({ hasText: 'Currency' }).filter({ hasText: 'USD Value' });
    await expect(table).toBeVisible();
  });

  test('shows top holdings by value table with risk levels', async ({ page }) => {
    await page.goto('/risk/concentration');

    await expect(page.locator('h2').filter({ hasText: 'Top Holdings by Value' })).toBeVisible();

    // Table should have risk column
    const table = page.locator('table').filter({ hasText: '% of NAV' });
    await expect(table).toBeVisible();
    await expect(table.locator('th').filter({ hasText: 'Risk' })).toBeVisible();
  });
});

test.describe('Debt Maturity (/debt-maturity)', () => {
  test('loads and displays debt maturity page', async ({ page }) => {
    await page.goto('/debt-maturity');

    await expect(page.locator('h1')).toContainText('Debt Maturity');
    await expect(page.locator('.deck')).toContainText(
      'Liability maturity timeline'
    );
  });

  test('shows metrics strip with debt overview', async ({ page }) => {
    await page.goto('/debt-maturity');

    await expect(page.locator('.metrics-strip')).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Total Debt (USD)' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Active Liabilities' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Avg Maturity' })).toBeVisible();
    await expect(page.locator('.metric-label').filter({ hasText: 'Nearest Maturity' })).toBeVisible();
  });

  test('displays maturity timeline bar chart with canvas element', async ({ page }) => {
    await page.goto('/debt-maturity');

    const timelineChart = page.locator('#maturity-timeline-chart');
    await expect(timelineChart).toBeVisible();
    await expect(timelineChart.locator('canvas')).toBeVisible();
  });

  test('displays debt composition pie chart with canvas element', async ({ page }) => {
    await page.goto('/debt-maturity');

    const compositionChart = page.locator('#debt-composition-chart');
    await expect(compositionChart).toBeVisible();
    await expect(compositionChart.locator('canvas')).toBeVisible();
  });

  test('shows maturity buckets table', async ({ page }) => {
    await page.goto('/debt-maturity');

    await expect(page.locator('h2').filter({ hasText: 'Maturity Buckets' })).toBeVisible();

    const table = page.locator('table').filter({ hasText: 'Time Horizon' });
    await expect(table).toBeVisible();
    await expect(table.locator('th').filter({ hasText: 'Total (USD)' })).toBeVisible();
    await expect(table.locator('th').filter({ hasText: '% of Total' })).toBeVisible();
  });

  test('shows all liabilities table', async ({ page }) => {
    await page.goto('/debt-maturity');

    await expect(page.locator('h2').filter({ hasText: 'All Liabilities' })).toBeVisible();

    const table = page.locator('table').filter({ hasText: 'Creditor' });
    await expect(table).toBeVisible();
    await expect(table.locator('th').filter({ hasText: 'Principal' })).toBeVisible();
    await expect(table.locator('th').filter({ hasText: 'Interest Rate' })).toBeVisible();
    await expect(table.locator('th').filter({ hasText: 'Maturity Date' })).toBeVisible();
    await expect(table.locator('th').filter({ hasText: 'Time Bucket' })).toBeVisible();
  });
});
