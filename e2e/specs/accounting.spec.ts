import { test, expect } from '@playwright/test';

// ---------------------------------------------------------------------------
// 1. Chart of Accounts  (/accounts/chart)
// ---------------------------------------------------------------------------
test.describe('Chart of Accounts', () => {
  test('loads and shows seeded accounts', async ({ page }) => {
    await page.goto('/accounts/chart');
    await expect(page.locator('h1')).toContainText('Chart of Accounts');

    const body = page.locator('body');
    // Verify a representative set of seeded accounts across all types
    await expect(body).toContainText('Cash');
    await expect(body).toContainText('Accounts Receivable');
    await expect(body).toContainText('Accounts Payable');
    await expect(body).toContainText("Owner's Equity");
    await expect(body).toContainText('Investment Income');
    await expect(body).toContainText('Operating Expenses');
  });

  test('shows account codes in the table', async ({ page }) => {
    await page.goto('/accounts/chart');

    const body = page.locator('body');
    await expect(body).toContainText('1000');
    await expect(body).toContainText('2000');
    await expect(body).toContainText('4000');
    await expect(body).toContainText('5000');
  });

  test('shows type counts in metrics strip', async ({ page }) => {
    await page.goto('/accounts/chart');

    // The metrics strip should show counts for each type
    await expect(page.locator('.metrics-strip')).toContainText('Assets');
    await expect(page.locator('.metrics-strip')).toContainText('Liabilities');
    await expect(page.locator('.metrics-strip')).toContainText('Equity');
    await expect(page.locator('.metrics-strip')).toContainText('Revenue');
    await expect(page.locator('.metrics-strip')).toContainText('Expenses');
  });

  test('filter by company', async ({ page }) => {
    await page.goto('/accounts/chart');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    // Select first real company (index 0 is "All Companies")
    await companySelect.selectOption({ index: 1 });
    // Page should still render without error
    await expect(page.locator('h1')).toContainText('Chart of Accounts');
  });

  test('create a new account', async ({ page }) => {
    await page.goto('/accounts/chart');

    // Open the form
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Fill in the form fields
    await page.locator('select[name="account[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="account[code]"]', '9900');
    await page.fill('input[name="account[name]"]', 'E2E Test Account');
    await page.locator('select[name="account[account_type]"]').selectOption('asset');
    await page.fill('input[name="account[currency]"]', 'USD');
    await page.fill('textarea[name="account[notes]"]', 'Created by E2E test');

    // Submit
    await page.locator('.dialog-panel button[type="submit"]').click();

    // Verify flash and new account appears in the table
    await expect(page.locator('body')).toContainText('Account created');
    await expect(page.locator('body')).toContainText('E2E Test Account');
    await expect(page.locator('body')).toContainText('9900');
  });

  test('delete the created account', async ({ page }) => {
    await page.goto('/accounts/chart');

    // Ensure the test account exists (created by prior test or seed)
    await expect(page.locator('body')).toContainText('E2E Test Account');

    // Accept the confirmation dialog before clicking delete
    page.on('dialog', (dialog) => dialog.accept());

    // Find the row containing our test account and click its delete button
    const row = page.locator('tr', { hasText: 'E2E Test Account' });
    await row.locator('[phx-click="delete"]').click();

    // Verify flash
    await expect(page.locator('body')).toContainText('Account deleted');
    // Account should no longer appear
    await expect(page.locator('body')).not.toContainText('E2E Test Account');
  });

  test('cancel form closes modal', async ({ page }) => {
    await page.goto('/accounts/chart');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Click cancel
    await page.locator('.dialog-panel [phx-click="close_form"]').click();

    // Modal should disappear
    await expect(page.locator('.dialog-panel')).not.toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 2. Journal Entries  (/accounts/journal)
// ---------------------------------------------------------------------------
test.describe('Journal Entries', () => {
  test('loads and shows seeded journal entries', async ({ page }) => {
    await page.goto('/accounts/journal');
    await expect(page.locator('h1')).toContainText('Journal Entries');

    const body = page.locator('body');
    // Verify seeded references JE-001 through JE-007
    await expect(body).toContainText('JE-001');
    await expect(body).toContainText('JE-003');
    await expect(body).toContainText('JE-005');
    await expect(body).toContainText('JE-007');
  });

  test('shows entry descriptions', async ({ page }) => {
    await page.goto('/accounts/journal');

    const body = page.locator('body');
    await expect(body).toContainText('Initial capital contribution');
    await expect(body).toContainText('Q4 2024 dividend received from Acme Tech');
  });

  test('filter by company', async ({ page }) => {
    await page.goto('/accounts/journal');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    // Select first real company
    await companySelect.selectOption({ index: 1 });
    // Page should still render
    await expect(page.locator('h1')).toContainText('Journal Entries');
  });

  test('expand and collapse a journal entry to see lines', async ({ page }) => {
    await page.goto('/accounts/journal');

    // Click the first entry row to expand it (toggle_entry)
    const firstEntryRow = page.locator('tr[phx-click="toggle_entry"]').first();
    await firstEntryRow.click();

    // After expanding, the detail rows should show account names
    // JE-001 has Cash and Owner's Equity lines
    await expect(page.locator('body')).toContainText('Cash');

    // Click again to collapse
    await firstEntryRow.click();
  });

  test('create a new journal entry with balanced lines', async ({ page }) => {
    await page.goto('/accounts/journal');

    // Open the form
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Fill entry header
    await page.locator('select[name="entry[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="entry[date]"]', '2025-06-01');
    await page.fill('input[name="entry[reference]"]', 'JE-E2E');
    await page.fill('input[name="entry[description]"]', 'E2E test journal entry');

    // Line 1: debit an account
    await page.locator('select[name="lines[0][account_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="lines[0][debit]"]', '1000');
    await page.fill('input[name="lines[0][credit]"]', '0');

    // Line 2: credit an account
    await page.locator('select[name="lines[1][account_id]"]').selectOption({ index: 2 });
    await page.fill('input[name="lines[1][debit]"]', '0');
    await page.fill('input[name="lines[1][credit]"]', '1000');

    // Submit
    await page.locator('.dialog-panel button[type="submit"]').click();

    // Verify flash and new entry in the list
    await expect(page.locator('body')).toContainText('Journal entry created');
    await expect(page.locator('body')).toContainText('E2E test journal entry');
    await expect(page.locator('body')).toContainText('JE-E2E');
  });

  test('validation rejects unbalanced journal entry', async ({ page }) => {
    await page.goto('/accounts/journal');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="entry[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="entry[date]"]', '2025-06-15');
    await page.fill('input[name="entry[description]"]', 'Unbalanced entry');

    // Line 1: debit 500
    await page.locator('select[name="lines[0][account_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="lines[0][debit]"]', '500');
    await page.fill('input[name="lines[0][credit]"]', '0');

    // Line 2: credit 300 (intentionally unbalanced)
    await page.locator('select[name="lines[1][account_id]"]').selectOption({ index: 2 });
    await page.fill('input[name="lines[1][debit]"]', '0');
    await page.fill('input[name="lines[1][credit]"]', '300');

    await page.locator('.dialog-panel button[type="submit"]').click();

    // Should show validation error about debits != credits
    await expect(page.locator('.dialog-panel')).toContainText('Debits');
    await expect(page.locator('.dialog-panel')).toContainText('must equal credits');
  });

  test('add line button adds a third line', async ({ page }) => {
    await page.goto('/accounts/journal');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Initially should have 2 line rows (lines[0] and lines[1])
    await expect(page.locator('select[name="lines[0][account_id]"]')).toBeVisible();
    await expect(page.locator('select[name="lines[1][account_id]"]')).toBeVisible();

    // Click add line
    await page.locator('[phx-click="add_line"]').click();

    // Now a third line should appear
    await expect(page.locator('select[name="lines[2][account_id]"]')).toBeVisible();
  });

  test('delete a journal entry', async ({ page }) => {
    await page.goto('/accounts/journal');

    // Ensure the E2E entry exists
    await expect(page.locator('body')).toContainText('JE-E2E');

    // Accept confirmation dialog
    page.on('dialog', (dialog) => dialog.accept());

    // Find the row with our test entry and delete it
    const row = page.locator('tr', { hasText: 'JE-E2E' });
    await row.locator('[phx-click="delete"]').click();

    // Verify flash
    await expect(page.locator('body')).toContainText('Journal entry deleted');
    // Entry should no longer appear
    await expect(page.locator('body')).not.toContainText('JE-E2E');
  });

  test('cancel form closes modal', async ({ page }) => {
    await page.goto('/accounts/journal');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('.dialog-panel [phx-click="close_form"]').click();
    await expect(page.locator('.dialog-panel')).not.toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 3. Accounting Reports  (/accounts/reports)
// ---------------------------------------------------------------------------
test.describe('Accounting Reports', () => {
  test('loads and shows trial balance by default', async ({ page }) => {
    await page.goto('/accounts/reports');
    await expect(page.locator('h1')).toContainText('Accounting Reports');

    // Trial balance tab should be active by default
    await expect(page.locator('body')).toContainText('Trial Balance');
    // Should show account data from seeded journal entries
    await expect(page.locator('body')).toContainText('Cash');
  });

  test('shows trial balance with debit/credit columns', async ({ page }) => {
    await page.goto('/accounts/reports');

    // Table headers
    await expect(page.locator('body')).toContainText('Debit');
    await expect(page.locator('body')).toContainText('Credit');
    await expect(page.locator('body')).toContainText('Balance');
  });

  test('switch to balance sheet tab', async ({ page }) => {
    await page.goto('/accounts/reports');

    // Click the Balance Sheet tab button
    await page.locator('button[phx-value-tab="balance_sheet"]').click();

    // Should show balance sheet sections
    await expect(page.locator('body')).toContainText('Assets');
    await expect(page.locator('body')).toContainText('Liabilities');
    await expect(page.locator('body')).toContainText('Equity');
    await expect(page.locator('body')).toContainText('Total Assets');
  });

  test('switch to income statement tab', async ({ page }) => {
    await page.goto('/accounts/reports');

    // Click the Income Statement tab button
    await page.locator('button[phx-value-tab="income_statement"]').click();

    // Should show revenue and expense sections
    await expect(page.locator('body')).toContainText('Revenue');
    await expect(page.locator('body')).toContainText('Expenses');
    await expect(page.locator('body')).toContainText('Net Income');
    await expect(page.locator('body')).toContainText('Total Revenue');
    await expect(page.locator('body')).toContainText('Total Expenses');
  });

  test('filter reports by company', async ({ page }) => {
    await page.goto('/accounts/reports');

    const companySelect = page.locator('form[phx-change="filter_company"] select[name="company_id"]');
    await expect(companySelect).toBeVisible();

    // "All Companies (Consolidated)" is the default
    await expect(companySelect).toContainText('All Companies');

    // Select a specific company
    await companySelect.selectOption({ index: 1 });
    // Page should still render
    await expect(page.locator('h1')).toContainText('Accounting Reports');
  });

  test('change display currency', async ({ page }) => {
    await page.goto('/accounts/reports');

    const currencySelect = page.locator('form[phx-change="change_currency"] select[name="currency"]');
    await expect(currencySelect).toBeVisible();

    // Switch to EUR
    await currencySelect.selectOption('EUR');
    // Page should update and mention EUR in deck text
    await expect(page.locator('body')).toContainText('EUR');
  });

  test('income statement date filter', async ({ page }) => {
    await page.goto('/accounts/reports');

    // Switch to income statement
    await page.locator('button[phx-value-tab="income_statement"]').click();

    // Date filters should be present
    const dateFrom = page.locator('input[name="date_from"]');
    const dateTo = page.locator('input[name="date_to"]');
    await expect(dateFrom).toBeVisible();
    await expect(dateTo).toBeVisible();

    // Change the date range
    await dateFrom.fill('2025-01-01');
    await dateTo.fill('2025-12-31');

    // Page should still render without error
    await expect(page.locator('body')).toContainText('Income Statement');
  });
});

// ---------------------------------------------------------------------------
// 4. QuickBooks Integration  (/accounts/integrations)
// ---------------------------------------------------------------------------
test.describe('QuickBooks Integration', () => {
  test('loads the integrations page', async ({ page }) => {
    await page.goto('/accounts/integrations');
    await expect(page.locator('h1')).toContainText('Integrations');
    await expect(page.locator('body')).toContainText('QuickBooks Online');
  });

  test('shows connection status', async ({ page }) => {
    await page.goto('/accounts/integrations');

    // Should show either Connected or Disconnected badge
    const body = page.locator('body');
    const hasConnected = await body.locator('.badge-asset', { hasText: 'Connected' }).count();
    const hasDisconnected = await body.locator('.badge-expense', { hasText: 'Disconnected' }).count();
    expect(hasConnected + hasDisconnected).toBeGreaterThan(0);
  });

  test('shows connect link when disconnected', async ({ page }) => {
    await page.goto('/accounts/integrations');

    const body = page.locator('body');
    const isDisconnected = await body.locator('.badge-expense', { hasText: 'Disconnected' }).count();

    if (isDisconnected > 0) {
      // Should show a "Connect to QuickBooks" link
      const connectLink = page.locator('a[href="/auth/quickbooks/connect"]');
      await expect(connectLink).toBeVisible();
      await expect(connectLink).toContainText('Connect to QuickBooks');
    }
  });

  test('shows sync controls when connected', async ({ page }) => {
    await page.goto('/accounts/integrations');

    const body = page.locator('body');
    const isConnected = await body.locator('.badge-asset', { hasText: 'Connected' }).count();

    if (isConnected > 0) {
      // Company selector for sync
      const companySelect = page.locator('form[phx-change="select_sync_company"] select[name="company_id"]');
      await expect(companySelect).toBeVisible();

      // Sync button
      const syncButton = page.locator('[phx-click="sync"]');
      await expect(syncButton).toBeVisible();

      // Disconnect button
      const disconnectButton = page.locator('[phx-click="disconnect"]');
      await expect(disconnectButton).toBeVisible();
    }
  });

  test('shows QuickBooks description text', async ({ page }) => {
    await page.goto('/accounts/integrations');

    await expect(page.locator('body')).toContainText(
      'Sync your chart of accounts and journal entries from QuickBooks Online'
    );
  });
});
