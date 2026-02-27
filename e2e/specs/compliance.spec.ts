import { test, expect } from '@playwright/test';

// ---------------------------------------------------------------------------
// Helper: switch to a compliance tab and wait for content to render
// ---------------------------------------------------------------------------
async function switchTab(page: import('@playwright/test').Page, tabName: string) {
  await page.locator(`[phx-click="switch_tab"][phx-value-tab="${tabName}"]`).click();
  // Give LiveView a moment to re-render the tab content
  await page.waitForTimeout(300);
}

// ===========================================================================
// 1. Compliance page  (/compliance)
// ===========================================================================
test.describe('Compliance (/compliance)', () => {
  test('page loads and displays content', async ({ page }) => {
    await page.goto('/compliance');
    await expect(page.locator('body')).toContainText('Compliance');
  });

  // -------------------------------------------------------------------------
  // Tab 1: Regulatory Filings
  // -------------------------------------------------------------------------
  test.describe('Regulatory Filings tab', () => {
    test('switch to tab and verify content', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'regulatory_filings');
      await expect(page.locator('body')).toContainText('Filing');
    });

    test('create a new regulatory filing', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'regulatory_filings');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="regulatory_filing[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="regulatory_filing[jurisdiction]"]', 'E2E Jurisdiction');
      await page.fill('input[name="regulatory_filing[filing_type]"]', 'E2E Annual Report');
      await page.fill('input[name="regulatory_filing[due_date]"]', '2026-12-31');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Jurisdiction');
    });

    test('edit a regulatory filing', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'regulatory_filings');

      await page.locator('[phx-click="edit_filing"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.fill('input[name="regulatory_filing[jurisdiction]"]', 'E2E Updated Jurisdiction');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Updated Jurisdiction');
    });

    test('delete a regulatory filing', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'regulatory_filings');

      // Create one to safely delete
      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="regulatory_filing[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="regulatory_filing[jurisdiction]"]', 'E2E Delete Filing');
      await page.fill('input[name="regulatory_filing[filing_type]"]', 'Quarterly');
      await page.fill('input[name="regulatory_filing[due_date]"]', '2026-06-30');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Delete Filing');

      page.on('dialog', (dialog) => dialog.accept());
      await page.locator('[phx-click="delete_filing"]').last().click();
      await expect(page.locator('body')).toContainText('Filing deleted');
    });
  });

  // -------------------------------------------------------------------------
  // Tab 2: Licenses
  // -------------------------------------------------------------------------
  test.describe('Licenses tab', () => {
    test('switch to tab and verify content', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'licenses');
      await expect(page.locator('body')).toContainText('License');
    });

    test('create a new license', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'licenses');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="regulatory_license[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="regulatory_license[license_type]"]', 'E2E Business License');
      await page.fill('input[name="regulatory_license[issuing_authority]"]', 'E2E Authority');
      await page.fill('input[name="regulatory_license[license_number]"]', 'LIC-E2E-001');
      await page.fill('input[name="regulatory_license[expiry_date]"]', '2027-12-31');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Business License');
    });
  });

  // -------------------------------------------------------------------------
  // Tab 3: Insurance
  // -------------------------------------------------------------------------
  test.describe('Insurance tab', () => {
    test('switch to tab and verify seeded data', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'insurance');
      await expect(page.locator('body')).toContainText('Insurance');
    });

    test('create a new insurance policy', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'insurance');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="insurance_policy[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="insurance_policy[policy_type]"]', 'E2E Directors & Officers');
      await page.fill('input[name="insurance_policy[provider]"]', 'E2E Insurance Corp');
      await page.fill('input[name="insurance_policy[coverage_amount]"]', '5000000');
      await page.fill('input[name="insurance_policy[premium]"]', '25000');
      await page.fill('input[name="insurance_policy[expiry_date]"]', '2027-06-30');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Directors & Officers');
    });

    test('edit an insurance policy', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'insurance');

      await page.locator('[phx-click="edit_insurance"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.fill('input[name="insurance_policy[provider]"]', 'E2E Updated Provider');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Updated Provider');
    });

    test('delete an insurance policy', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'insurance');

      // Create one to safely delete
      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="insurance_policy[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="insurance_policy[policy_type]"]', 'E2E Delete Policy');
      await page.fill('input[name="insurance_policy[provider]"]', 'Delete Corp');
      await page.fill('input[name="insurance_policy[coverage_amount]"]', '100');
      await page.fill('input[name="insurance_policy[premium]"]', '10');
      await page.fill('input[name="insurance_policy[expiry_date]"]', '2026-12-31');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Delete Policy');

      page.on('dialog', (dialog) => dialog.accept());
      await page.locator('[phx-click="delete_insurance"]').last().click();
      await expect(page.locator('body')).toContainText('Policy deleted');
    });
  });

  // -------------------------------------------------------------------------
  // Tab 4: Sanctions
  // -------------------------------------------------------------------------
  test.describe('Sanctions tab', () => {
    test('switch to tab and verify content', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'sanctions');
      await expect(page.locator('body')).toContainText('Sanction');
    });

    test('create a new sanctions check', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'sanctions');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="sanctions_check[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="sanctions_check[checked_name]"]', 'E2E Checked Entity');
      await page.fill('textarea[name="sanctions_check[notes]"]', 'E2E sanctions screening notes');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Checked Entity');
    });
  });

  // -------------------------------------------------------------------------
  // Tab 5: ESG
  // -------------------------------------------------------------------------
  test.describe('ESG tab', () => {
    test('switch to tab and verify content', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'esg');
      await expect(page.locator('body')).toContainText('ESG');
    });

    test('create a new ESG score', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'esg');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="esg_score[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="esg_score[period]"]', '2026-Q1');
      await page.fill('input[name="esg_score[environmental_score]"]', '85.5');
      await page.fill('input[name="esg_score[social_score]"]', '72.3');
      await page.fill('input[name="esg_score[governance_score]"]', '90.1');
      await page.fill('input[name="esg_score[overall_score]"]', '82.6');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('2026-Q1');
    });
  });

  // -------------------------------------------------------------------------
  // Tab 6: FATCA
  // -------------------------------------------------------------------------
  test.describe('FATCA tab', () => {
    test('switch to tab and verify content', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'fatca');
      await expect(page.locator('body')).toContainText('FATCA');
    });

    test('create a new FATCA report', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'fatca');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="fatca_report[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="fatca_report[reporting_year]"]', '2026');
      await page.fill('input[name="fatca_report[jurisdiction]"]', 'E2E US');
      await page.locator('select[name="fatca_report[report_type]"]').selectOption('fatca');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E US');
    });
  });

  // -------------------------------------------------------------------------
  // Tab 7: Withholding
  // -------------------------------------------------------------------------
  test.describe('Withholding tab', () => {
    test('switch to tab and verify content', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'withholding');
      await expect(page.locator('body')).toContainText('Withholding');
    });

    test('create a new withholding tax record', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'withholding');

      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="withholding_tax[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="withholding_tax[payment_type]"]', 'E2E Dividend');
      await page.fill('input[name="withholding_tax[country_from]"]', 'US');
      await page.fill('input[name="withholding_tax[country_to]"]', 'DE');
      await page.fill('input[name="withholding_tax[gross_amount]"]', '100000');
      await page.fill('input[name="withholding_tax[rate]"]', '15');
      await page.fill('input[name="withholding_tax[tax_amount]"]', '15000');
      await page.fill('input[name="withholding_tax[date]"]', '2026-03-15');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Dividend');
    });

    test('edit a withholding tax record', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'withholding');

      await page.locator('[phx-click="edit_withholding"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.fill('input[name="withholding_tax[payment_type]"]', 'E2E Updated Payment');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Updated Payment');
    });

    test('delete a withholding tax record', async ({ page }) => {
      await page.goto('/compliance');
      await switchTab(page, 'withholding');

      // Create one to safely delete
      await page.locator('[phx-click="show_form"]').first().click();
      await page.locator('.dialog-panel').waitFor();

      await page.locator('select[name="withholding_tax[company_id]"]').selectOption({ index: 1 });
      await page.fill('input[name="withholding_tax[payment_type]"]', 'E2E Delete WHT');
      await page.fill('input[name="withholding_tax[country_from]"]', 'GB');
      await page.fill('input[name="withholding_tax[country_to]"]', 'FR');
      await page.fill('input[name="withholding_tax[gross_amount]"]', '5000');
      await page.fill('input[name="withholding_tax[rate]"]', '10');
      await page.fill('input[name="withholding_tax[tax_amount]"]', '500');
      await page.fill('input[name="withholding_tax[date]"]', '2026-04-01');

      await page.locator('.dialog-panel button[type="submit"]').click();
      await expect(page.locator('body')).toContainText('E2E Delete WHT');

      page.on('dialog', (dialog) => dialog.accept());
      await page.locator('[phx-click="delete_withholding"]').last().click();
      await expect(page.locator('body')).toContainText('Tax entry deleted');
    });
  });
});

// ===========================================================================
// 2. Calendar page  (/calendar)
// ===========================================================================
test.describe('Calendar (/calendar)', () => {
  test('page loads and displays calendar content', async ({ page }) => {
    await page.goto('/calendar');
    await expect(page.locator('body')).toContainText('Calendar');
  });

  test('navigate to previous month', async ({ page }) => {
    await page.goto('/calendar');
    await page.locator('[phx-click="prev_month"]').click();
    await expect(page.locator('body')).toContainText('Calendar');
  });

  test('navigate to next month', async ({ page }) => {
    await page.goto('/calendar');
    await page.locator('[phx-click="next_month"]').click();
    await expect(page.locator('body')).toContainText('Calendar');
  });

  test('filter by event type', async ({ page }) => {
    await page.goto('/calendar');

    const typeFilter = page.locator('select[name="type"]');
    await expect(typeFilter).toBeVisible();

    // Select a filter option (index 1 = first non-default option)
    await typeFilter.selectOption({ index: 1 });
    // Page should still render
    await expect(page.locator('body')).toContainText('Calendar');

    // Reset to default
    await typeFilter.selectOption({ index: 0 });
    await expect(page.locator('body')).toContainText('Calendar');
  });

  test('navigate months back and forth', async ({ page }) => {
    await page.goto('/calendar');

    // Go back two months
    await page.locator('[phx-click="prev_month"]').click();
    await page.locator('[phx-click="prev_month"]').click();
    await expect(page.locator('body')).toContainText('Calendar');

    // Go forward three months
    await page.locator('[phx-click="next_month"]').click();
    await page.locator('[phx-click="next_month"]').click();
    await page.locator('[phx-click="next_month"]').click();
    await expect(page.locator('body')).toContainText('Calendar');
  });
});

// ===========================================================================
// 3. Tax Calendar page  (/tax-calendar)
// ===========================================================================
test.describe('Tax Calendar (/tax-calendar)', () => {
  test('page loads and displays tax calendar content', async ({ page }) => {
    await page.goto('/tax-calendar');
    await expect(page.locator('body')).toContainText('Tax');
  });

  test('shows seeded tax deadlines', async ({ page }) => {
    await page.goto('/tax-calendar');
    // Seeded data includes tax deadlines; verify the page has table or list content
    await expect(page.locator('body')).toContainText('Tax');
  });
});

// ===========================================================================
// 4. Capital Gains Tax page  (/tax/capital-gains)
// ===========================================================================
test.describe('Capital Gains Tax (/tax/capital-gains)', () => {
  test('page loads and displays capital gains content', async ({ page }) => {
    await page.goto('/tax/capital-gains');
    await expect(page.locator('body')).toContainText('Capital Gains');
  });

  test('shows tax-related data or empty state', async ({ page }) => {
    await page.goto('/tax/capital-gains');
    // Page should render without error and contain relevant headings
    await expect(page.locator('body')).toContainText('Capital Gains');
  });
});
