import { test, expect } from '@playwright/test';

test.describe('Companies List Page', () => {
  test('loads and displays seeded companies', async ({ page }) => {
    await page.goto('/companies');
    await expect(page.locator('body')).toContainText('Companies');
    await expect(page.locator('body')).toContainText('Acme Holdings');
    await expect(page.locator('body')).toContainText('Acme Tech');
    await expect(page.locator('body')).toContainText('Acme Capital');
    await expect(page.locator('body')).toContainText('Acme Media');
    await expect(page.locator('body')).toContainText('Acme Retail');
  });

  test('switch between list and tree view', async ({ page }) => {
    await page.goto('/companies');
    await expect(page.locator('body')).toContainText('Acme Holdings');

    // Switch to tree view
    await page.locator('[phx-click="set_view"][phx-value-mode="tree"]').click();
    await expect(page.locator('body')).toContainText('Acme Holdings');

    // Switch back to list view
    await page.locator('[phx-click="set_view"][phx-value-mode="list"]').click();
    await expect(page.locator('body')).toContainText('Acme Holdings');
  });

  test('export CSV link is present', async ({ page }) => {
    await page.goto('/companies');
    const csvLink = page.locator('a[href="/export/companies.csv"]');
    await expect(csvLink).toBeVisible();
  });

  test('create a new company via modal', async ({ page }) => {
    await page.goto('/companies/new');

    // Modal should be visible
    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    // Fill in all company fields
    await modal.locator('input[name="company[name]"]').fill('E2E Test Corp');
    await modal.locator('input[name="company[country]"]').fill('Uruguay');
    await modal.locator('input[name="company[category]"]').fill('Technology');

    // Select parent company (pick first option if available)
    const parentSelect = modal.locator('select[name="company[parent_id]"]');
    if (await parentSelect.isVisible()) {
      await parentSelect.selectOption({ index: 1 });
    }

    // Set ownership percentage
    const ownershipInput = modal.locator('input[name="company[ownership_pct]"]');
    if (await ownershipInput.isVisible()) {
      await ownershipInput.fill('75');
    }

    // Check the is_holding checkbox
    const holdingCheckbox = modal.locator('input[name="company[is_holding]"]');
    if (await holdingCheckbox.isVisible()) {
      await holdingCheckbox.check();
    }

    // Submit the form
    await modal.locator('button[type="submit"]').click();

    // Verify flash message
    await expect(page.locator('body')).toContainText('Company created');

    // Verify the new company appears in the list
    await expect(page.locator('body')).toContainText('E2E Test Corp');
  });

  test('delete a company', async ({ page }) => {
    // First create a company to delete
    await page.goto('/companies/new');
    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    await modal.locator('input[name="company[name]"]').fill('Company To Delete');
    await modal.locator('input[name="company[country]"]').fill('Argentina');

    await modal.locator('button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Company created');

    // Now delete it - accept the confirmation dialog
    page.on('dialog', (dialog) => dialog.accept());

    // Find the delete button for "Company To Delete"
    const row = page.locator('tr', { hasText: 'Company To Delete' });
    await row.locator('[phx-click="delete"]').click();

    await expect(page.locator('body')).toContainText('Company deleted');
  });
});

test.describe('Company Show Page - Overview', () => {
  test('navigate to company show page and verify overview', async ({ page }) => {
    await page.goto('/companies');

    // Click on Acme Holdings to go to its show page
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Overview tab should be active by default
    await expect(page.locator('body')).toContainText('Acme Holdings');
  });
});

test.describe('Company Show Page - Tab Navigation', () => {
  let companyUrl: string;

  test.beforeEach(async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);
    companyUrl = page.url();
  });

  test('switch to holdings tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="holdings"]').click();
    await expect(page.locator('body')).toContainText('Holdings');
  });

  test('switch to bank_accounts tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="bank_accounts"]').click();
    await expect(page.locator('body')).toContainText('Bank');
  });

  test('switch to transactions tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="transactions"]').click();
    await expect(page.locator('body')).toContainText('Transaction');
  });

  test('switch to documents tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="documents"]').click();
    await expect(page.locator('body')).toContainText('Document');
  });

  test('switch to governance tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="governance"]').click();
    await expect(page.locator('body')).toContainText('Governance');
  });

  test('switch to compliance tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="compliance"]').click();
    await expect(page.locator('body')).toContainText('Compliance');
  });

  test('switch to financials tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="financials"]').click();
    await expect(page.locator('body')).toContainText('Financial');
  });

  test('switch to accounting tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="accounting"]').click();
    await expect(page.locator('body')).toContainText('Accounting');
  });

  test('switch to comments tab', async ({ page }) => {
    await page.locator('[phx-click="switch_tab"][phx-value-tab="comments"]').click();
    await expect(page.locator('body')).toContainText('Comment');
  });
});

test.describe('Company Show Page - Holdings CRUD', () => {
  test('add a new holding', async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Switch to holdings tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="holdings"]').click();
    await expect(page.locator('body')).toContainText('Holdings');

    // Click the Add button to show the form
    await page.locator('[phx-click="show_form"]').first().click();

    // Fill in the holding form inside the modal
    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    // Select a company
    const companySelect = modal.locator('select[name="holding[company_id]"]');
    if (await companySelect.isVisible()) {
      await companySelect.selectOption({ index: 1 });
    }

    await modal.locator('input[name="holding[asset]"]').fill('Apple Inc');
    await modal.locator('input[name="holding[ticker]"]').fill('AAPL');
    await modal.locator('input[name="holding[quantity]"]').fill('1000');
    await modal.locator('input[name="holding[unit]"]').fill('shares');

    const assetTypeSelect = modal.locator('select[name="holding[asset_type]"]');
    if (await assetTypeSelect.isVisible()) {
      await assetTypeSelect.selectOption({ index: 1 });
    }

    await modal.locator('input[name="holding[currency]"]').fill('USD');

    // Submit the form
    await modal.locator('button[type="submit"]').click();

    // Verify flash message
    await expect(page.locator('body')).toContainText('Holding added');

    // Verify the holding appears in the list
    await expect(page.locator('body')).toContainText('Apple Inc');
  });
});

test.describe('Company Show Page - Bank Accounts CRUD', () => {
  test('add a new bank account', async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Switch to bank_accounts tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="bank_accounts"]').click();
    await expect(page.locator('body')).toContainText('Bank');

    // Click the Add button
    await page.locator('[phx-click="show_form"]').first().click();

    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    // Select a company
    const companySelect = modal.locator('select[name="bank_account[company_id]"]');
    if (await companySelect.isVisible()) {
      await companySelect.selectOption({ index: 1 });
    }

    await modal.locator('input[name="bank_account[bank_name]"]').fill('HSBC');
    await modal.locator('input[name="bank_account[account_number]"]').fill('123456789');
    await modal.locator('input[name="bank_account[iban]"]').fill('GB82WEST12345698765432');
    await modal.locator('input[name="bank_account[swift]"]').fill('HSBCGB2L');
    await modal.locator('input[name="bank_account[currency]"]').fill('GBP');

    // Select account type
    const accountTypeSelect = modal.locator('select[name="bank_account[account_type]"]');
    if (await accountTypeSelect.isVisible()) {
      await accountTypeSelect.selectOption('operating');
    }

    await modal.locator('input[name="bank_account[balance]"]').fill('500000');

    // Submit
    await modal.locator('button[type="submit"]').click();

    // Verify flash message
    await expect(page.locator('body')).toContainText('Bank account added');

    // Verify the bank account appears
    await expect(page.locator('body')).toContainText('HSBC');
  });
});

test.describe('Company Show Page - Transactions CRUD', () => {
  test('add a new transaction', async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Switch to transactions tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="transactions"]').click();
    await expect(page.locator('body')).toContainText('Transaction');

    // Click the Add button
    await page.locator('[phx-click="show_form"]').first().click();

    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    // Select a company
    const companySelect = modal.locator('select[name="transaction[company_id]"]');
    if (await companySelect.isVisible()) {
      await companySelect.selectOption({ index: 1 });
    }

    await modal.locator('input[name="transaction[date]"]').fill('2026-02-26');
    await modal.locator('input[name="transaction[transaction_type]"]').fill('wire_transfer');
    await modal.locator('input[name="transaction[amount]"]').fill('25000');
    await modal.locator('input[name="transaction[currency]"]').fill('USD');
    await modal.locator('input[name="transaction[description]"]').fill('Q1 dividend payment');
    await modal.locator('input[name="transaction[counterparty]"]').fill('Acme Tech');

    // Submit
    await modal.locator('button[type="submit"]').click();

    // Verify flash message
    await expect(page.locator('body')).toContainText('Transaction added');

    // Verify the transaction appears
    await expect(page.locator('body')).toContainText('Q1 dividend payment');
  });
});

test.describe('Company Show Page - Documents CRUD', () => {
  test('add a new document', async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Switch to documents tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="documents"]').click();
    await expect(page.locator('body')).toContainText('Document');

    // Click the Add button
    await page.locator('[phx-click="show_form"]').first().click();

    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    // Select a company
    const companySelect = modal.locator('select[name="document[company_id]"]');
    if (await companySelect.isVisible()) {
      await companySelect.selectOption({ index: 1 });
    }

    await modal.locator('input[name="document[name]"]').fill('Annual Report 2025');
    await modal.locator('input[name="document[doc_type]"]').fill('annual_report');
    await modal.locator('input[name="document[url]"]').fill('https://docs.example.com/annual-2025.pdf');
    await modal.locator('textarea[name="document[notes]"]').fill('Final audited annual report for fiscal year 2025');

    // Submit
    await modal.locator('button[type="submit"]').click();

    // Verify flash message
    await expect(page.locator('body')).toContainText('Document added');

    // Verify the document appears
    await expect(page.locator('body')).toContainText('Annual Report 2025');
  });
});

test.describe('Company Show Page - Financials CRUD', () => {
  test('add a new financial record', async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Switch to financials tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="financials"]').click();
    await expect(page.locator('body')).toContainText('Financial');

    // Click the Add button
    await page.locator('[phx-click="show_form"]').first().click();

    const modal = page.locator('.dialog-panel');
    await expect(modal).toBeVisible();

    // Select a company
    const companySelect = modal.locator('select[name="financial[company_id]"]');
    if (await companySelect.isVisible()) {
      await companySelect.selectOption({ index: 1 });
    }

    await modal.locator('input[name="financial[period]"]').fill('2025-Q4');
    await modal.locator('input[name="financial[revenue]"]').fill('1500000');
    await modal.locator('input[name="financial[expenses]"]').fill('980000');

    // Submit
    await modal.locator('button[type="submit"]').click();

    // Verify flash message
    await expect(page.locator('body')).toContainText('Financial record added');

    // Verify the financial record appears
    await expect(page.locator('body')).toContainText('2025-Q4');
  });
});

test.describe('Company Show Page - Comments', () => {
  test('add a comment', async ({ page }) => {
    await page.goto('/companies');
    await page.locator('a', { hasText: 'Acme Holdings' }).first().click();
    await page.waitForURL(/\/companies\/\d+/);

    // Switch to comments tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="comments"]').click();
    await expect(page.locator('body')).toContainText('Comment');

    // Fill in the comment form (comments form is inline, not in a modal)
    await page.locator('textarea[name="comment[body]"]').fill(
      'This is an E2E test comment for Acme Holdings. Board meeting notes to follow.'
    );

    // Submit the comment form
    await page.locator('form[phx-submit="save_comment"] button[type="submit"]').click();

    // Verify the comment appears
    await expect(page.locator('body')).toContainText('E2E test comment');
  });
});
