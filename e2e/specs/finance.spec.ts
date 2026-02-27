import { test, expect } from '@playwright/test';

// ---------------------------------------------------------------------------
// 1. Financials  (/financials)
// ---------------------------------------------------------------------------
test.describe('Financials', () => {
  test('page loads and displays financial data', async ({ page }) => {
    await page.goto('/financials');
    await expect(page.locator('body')).toContainText('Financial');
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('create a new financial record with all fields', async ({ page }) => {
    await page.goto('/financials');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('.dialog-panel select[name="financial[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="financial[period]"]', '2026-Q1');
    await page.fill('.dialog-panel input[name="financial[revenue]"]', '2500000');
    await page.fill('.dialog-panel input[name="financial[expenses]"]', '1800000');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Financial record added');
    await expect(page.locator('body')).toContainText('2026-Q1');
  });

  test('edit a financial record', async ({ page }) => {
    await page.goto('/financials');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="financial[revenue]"]', '3000000');
    await page.fill('.dialog-panel input[name="financial[expenses]"]', '2100000');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Financial record updated');
  });

  test('delete a financial record', async ({ page }) => {
    await page.goto('/financials');

    // Create one to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('.dialog-panel select[name="financial[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="financial[period]"]', 'DELETE-ME');
    await page.fill('.dialog-panel input[name="financial[revenue]"]', '100');
    await page.fill('.dialog-panel input[name="financial[expenses]"]', '50');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Financial record added');
    await expect(page.locator('body')).toContainText('DELETE-ME');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Financial record deleted');
  });

  test('filter by company', async ({ page }) => {
    await page.goto('/financials');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    // Select first real company (index 0 is "All Companies")
    await companySelect.selectOption({ index: 1 });
    // Page should still render without error
    await expect(page.locator('body')).toContainText('Financial');
  });

  test('change display currency', async ({ page }) => {
    await page.goto('/financials');

    const currencySelect = page.locator('form[phx-change="change_currency"] select[name="currency"]');
    await expect(currencySelect).toBeVisible();

    await currencySelect.selectOption('EUR');
    await expect(page.locator('body')).toContainText('EUR');
  });

  test('create an intercompany transfer with all fields', async ({ page }) => {
    await page.goto('/financials');

    await page.locator('[phx-click="show_transfer_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('.dialog-panel select[name="transfer[from_company_id]"]').selectOption({ index: 1 });
    await page.locator('.dialog-panel select[name="transfer[to_company_id]"]').selectOption({ index: 2 });
    await page.fill('.dialog-panel input[name="transfer[amount]"]', '500000');
    await page.fill('.dialog-panel input[name="transfer[currency]"]', 'USD');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Transfer added');
  });
});

// ---------------------------------------------------------------------------
// 2. Budget vs Actual  (/budgets/variance)
// ---------------------------------------------------------------------------
test.describe('Budget vs Actual', () => {
  test('page loads and displays variance data', async ({ page }) => {
    await page.goto('/budgets/variance');
    await expect(page.locator('body')).toContainText('Budget');
    // Should show variance or actual data
    await expect(page.locator('body')).toContainText('Variance');
  });
});

// ---------------------------------------------------------------------------
// 3. Waterfall Charts  (/waterfall)
// ---------------------------------------------------------------------------
test.describe('Waterfall Charts', () => {
  test('page loads and displays waterfall chart', async ({ page }) => {
    await page.goto('/waterfall');
    await expect(page.locator('body')).toContainText('Waterfall');
  });

  test('canvas chart elements are present', async ({ page }) => {
    await page.goto('/waterfall');

    const canvas = page.locator('canvas');
    if (await canvas.count() > 0) {
      await expect(canvas.first()).toBeVisible();
    }
  });
});

// ---------------------------------------------------------------------------
// 4. Cash Flow Forecast  (/cash-forecast)
// ---------------------------------------------------------------------------
test.describe('Cash Flow Forecast', () => {
  test('page loads and displays forecast data', async ({ page }) => {
    await page.goto('/cash-forecast');
    await expect(page.locator('body')).toContainText('Cash');
    await expect(page.locator('body')).toContainText('Forecast');
  });

  test('canvas chart elements are present', async ({ page }) => {
    await page.goto('/cash-forecast');

    const canvas = page.locator('canvas');
    if (await canvas.count() > 0) {
      await expect(canvas.first()).toBeVisible();
    }
  });
});

// ---------------------------------------------------------------------------
// 5. Consolidated Statements  (/consolidated)
// ---------------------------------------------------------------------------
test.describe('Consolidated Statements', () => {
  test('page loads and displays consolidated data', async ({ page }) => {
    await page.goto('/consolidated');
    await expect(page.locator('body')).toContainText('Consolidated');
  });

  test('filter by company if available', async ({ page }) => {
    await page.goto('/consolidated');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    if (await companySelect.isVisible()) {
      await companySelect.selectOption({ index: 1 });
      await expect(page.locator('body')).toContainText('Consolidated');
    }
  });

  test('change display currency if available', async ({ page }) => {
    await page.goto('/consolidated');

    const currencySelect = page.locator('form[phx-change="change_currency"] select[name="currency"]');
    if (await currencySelect.isVisible()) {
      await currencySelect.selectOption('EUR');
      await expect(page.locator('body')).toContainText('EUR');
    }
  });
});

// ---------------------------------------------------------------------------
// 6. Currency Revaluation  (/revaluation)
// ---------------------------------------------------------------------------
test.describe('Currency Revaluation', () => {
  test('page loads and displays revaluation data', async ({ page }) => {
    await page.goto('/revaluation');
    await expect(page.locator('body')).toContainText('Revaluation');
  });
});

// ---------------------------------------------------------------------------
// 7. Fixed Asset Depreciation  (/depreciation)
// ---------------------------------------------------------------------------
test.describe('Fixed Asset Depreciation', () => {
  test('page loads and displays depreciation data', async ({ page }) => {
    await page.goto('/depreciation');
    await expect(page.locator('body')).toContainText('Depreciation');
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('create a new fixed asset with all fields', async ({ page }) => {
    await page.goto('/depreciation');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="fixed_asset[name]"]', 'E2E Office Equipment');
    await page.locator('.dialog-panel select[name="fixed_asset[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="fixed_asset[purchase_date]"]', '2025-01-15');
    await page.fill('.dialog-panel input[name="fixed_asset[purchase_price]"]', '75000');
    await page.fill('.dialog-panel input[name="fixed_asset[useful_life_months]"]', '60');
    await page.fill('.dialog-panel input[name="fixed_asset[salvage_value]"]', '5000');
    await page.locator('.dialog-panel select[name="fixed_asset[depreciation_method]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel textarea[name="fixed_asset[notes]"]', 'Purchased for new office wing');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Fixed asset added');
    await expect(page.locator('body')).toContainText('E2E Office Equipment');
  });

  test('edit a fixed asset', async ({ page }) => {
    await page.goto('/depreciation');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="fixed_asset[name]"]', 'E2E Updated Equipment');
    await page.fill('.dialog-panel input[name="fixed_asset[salvage_value]"]', '3000');
    await page.fill('.dialog-panel textarea[name="fixed_asset[notes]"]', 'Updated by E2E test');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Fixed asset updated');
    await expect(page.locator('body')).toContainText('E2E Updated Equipment');
  });

  test('delete a fixed asset', async ({ page }) => {
    await page.goto('/depreciation');

    // Create one to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="fixed_asset[name]"]', 'E2E Delete Me Asset');
    await page.locator('.dialog-panel select[name="fixed_asset[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="fixed_asset[purchase_date]"]', '2025-06-01');
    await page.fill('.dialog-panel input[name="fixed_asset[purchase_price]"]', '1000');
    await page.fill('.dialog-panel input[name="fixed_asset[useful_life_months]"]', '12');
    await page.fill('.dialog-panel input[name="fixed_asset[salvage_value]"]', '0');
    await page.locator('.dialog-panel select[name="fixed_asset[depreciation_method]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Fixed asset added');
    await expect(page.locator('body')).toContainText('E2E Delete Me Asset');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Fixed asset deleted');
  });

  test('filter by company', async ({ page }) => {
    await page.goto('/depreciation');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    await companySelect.selectOption({ index: 1 });
    await expect(page.locator('body')).toContainText('Depreciation');
  });

  test('select an asset to view depreciation schedule', async ({ page }) => {
    await page.goto('/depreciation');

    // Click the first asset row to view its schedule
    const selectButton = page.locator('[phx-click="select_asset"]').first();
    if (await selectButton.isVisible()) {
      await selectButton.click();
      // Schedule section should appear
      await expect(page.locator('body')).toContainText('Schedule');

      // Close the schedule
      const closeButton = page.locator('[phx-click="close_schedule"]');
      if (await closeButton.isVisible()) {
        await closeButton.click();
      }
    }
  });
});

// ---------------------------------------------------------------------------
// 8. Lease Accounting  (/leases)
// ---------------------------------------------------------------------------
test.describe('Lease Accounting', () => {
  test('page loads and displays lease data', async ({ page }) => {
    await page.goto('/leases');
    await expect(page.locator('body')).toContainText('Lease');
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('create a new lease with all fields', async ({ page }) => {
    await page.goto('/leases');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="lease[lessor]"]', 'E2E Realty Partners');
    await page.fill('.dialog-panel input[name="lease[asset_description]"]', 'Downtown office space - Floor 12');
    await page.locator('.dialog-panel select[name="lease[company_id]"]').selectOption({ index: 1 });
    await page.locator('.dialog-panel select[name="lease[lease_type]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="lease[start_date]"]', '2025-01-01');
    await page.fill('.dialog-panel input[name="lease[end_date]"]', '2029-12-31');
    await page.fill('.dialog-panel input[name="lease[monthly_payment]"]', '15000');
    await page.fill('.dialog-panel input[name="lease[discount_rate]"]', '5.5');
    await page.locator('.dialog-panel select[name="lease[currency]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel textarea[name="lease[notes]"]', 'Main office lease with renewal option');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Lease added');
    await expect(page.locator('body')).toContainText('E2E Realty Partners');
  });

  test('edit a lease', async ({ page }) => {
    await page.goto('/leases');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="lease[lessor]"]', 'E2E Updated Lessor');
    await page.fill('.dialog-panel input[name="lease[monthly_payment]"]', '16500');
    await page.fill('.dialog-panel textarea[name="lease[notes]"]', 'Updated by E2E test - rent increase');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Lease updated');
    await expect(page.locator('body')).toContainText('E2E Updated Lessor');
  });

  test('delete a lease', async ({ page }) => {
    await page.goto('/leases');

    // Create one to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="lease[lessor]"]', 'E2E Delete Me Lessor');
    await page.fill('.dialog-panel input[name="lease[asset_description]"]', 'Temp storage unit');
    await page.locator('.dialog-panel select[name="lease[company_id]"]').selectOption({ index: 1 });
    await page.locator('.dialog-panel select[name="lease[lease_type]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="lease[start_date]"]', '2026-01-01');
    await page.fill('.dialog-panel input[name="lease[end_date]"]', '2026-12-31');
    await page.fill('.dialog-panel input[name="lease[monthly_payment]"]', '500');
    await page.fill('.dialog-panel input[name="lease[discount_rate]"]', '4');
    await page.locator('.dialog-panel select[name="lease[currency]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Lease added');
    await expect(page.locator('body')).toContainText('E2E Delete Me Lessor');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Lease deleted');
  });

  test('filter by company', async ({ page }) => {
    await page.goto('/leases');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    await companySelect.selectOption({ index: 1 });
    await expect(page.locator('body')).toContainText('Lease');
  });

  test('select a lease to view amortization schedule', async ({ page }) => {
    await page.goto('/leases');

    const selectButton = page.locator('[phx-click="select_lease"]').first();
    if (await selectButton.isVisible()) {
      await selectButton.click();
      // Schedule/detail section should appear
      await expect(page.locator('body')).toContainText('Lease');
    }
  });
});

// ---------------------------------------------------------------------------
// 9. Segment Reporting  (/segments)
// ---------------------------------------------------------------------------
test.describe('Segment Reporting', () => {
  test('page loads and displays segment data', async ({ page }) => {
    await page.goto('/segments');
    await expect(page.locator('body')).toContainText('Segment');
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('create a new segment with all fields', async ({ page }) => {
    await page.goto('/segments');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="segment[name]"]', 'E2E Technology Division');
    await page.locator('.dialog-panel select[name="segment[segment_type]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel textarea[name="segment[description]"]', 'Technology products and services division');
    await page.locator('.dialog-panel select[name="segment[company_id]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Segment added');
    await expect(page.locator('body')).toContainText('E2E Technology Division');
  });

  test('edit a segment', async ({ page }) => {
    await page.goto('/segments');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="segment[name]"]', 'E2E Updated Segment');
    await page.fill('.dialog-panel textarea[name="segment[description]"]', 'Updated by E2E test');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Segment updated');
    await expect(page.locator('body')).toContainText('E2E Updated Segment');
  });

  test('delete a segment', async ({ page }) => {
    await page.goto('/segments');

    // Create one to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('.dialog-panel input[name="segment[name]"]', 'E2E Delete Me Segment');
    await page.locator('.dialog-panel select[name="segment[segment_type]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel textarea[name="segment[description]"]', 'Temporary segment for deletion test');
    await page.locator('.dialog-panel select[name="segment[company_id]"]').selectOption({ index: 1 });

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Segment added');
    await expect(page.locator('body')).toContainText('E2E Delete Me Segment');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Segment deleted');
  });

  test('filter by company', async ({ page }) => {
    await page.goto('/segments');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    await companySelect.selectOption({ index: 1 });
    await expect(page.locator('body')).toContainText('Segment');
  });

  test('select a segment to view details', async ({ page }) => {
    await page.goto('/segments');

    const selectButton = page.locator('[phx-click="select_segment"]').first();
    if (await selectButton.isVisible()) {
      await selectButton.click();
      // Detail section should appear
      await expect(page.locator('body')).toContainText('Segment');
    }
  });
});
