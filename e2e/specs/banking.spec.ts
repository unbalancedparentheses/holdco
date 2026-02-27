import { test, expect } from '@playwright/test';

test.describe('Bank Accounts', () => {
  test('list page loads with seeded data', async ({ page }) => {
    await page.goto('/bank-accounts');
    await expect(page.locator('body')).toContainText('Bank Account');
    // Seeded companies should have bank accounts visible
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('create a new bank account with all fields', async ({ page }) => {
    await page.goto('/bank-accounts');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="bank_account[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="bank_account[bank_name]"]', 'E2E Test Bank');
    await page.fill('input[name="bank_account[account_number]"]', 'ACCT-999-E2E');
    await page.fill('input[name="bank_account[iban]"]', 'DE89370400440532013000');
    await page.fill('input[name="bank_account[swift]"]', 'COBADEFFXXX');
    await page.fill('input[name="bank_account[currency]"]', 'EUR');
    await page.locator('select[name="bank_account[account_type]"]').selectOption('escrow');
    await page.fill('input[name="bank_account[balance]"]', '250000.50');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Bank account added');
    await expect(page.locator('body')).toContainText('E2E Test Bank');
  });

  test('edit a bank account', async ({ page }) => {
    await page.goto('/bank-accounts');

    // Click the first edit button in the list
    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="bank_account[bank_name]"]', 'E2E Updated Bank');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Bank account updated');
    await expect(page.locator('body')).toContainText('E2E Updated Bank');
  });

  test('delete a bank account', async ({ page }) => {
    await page.goto('/bank-accounts');

    // First create one to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="bank_account[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="bank_account[bank_name]"]', 'E2E Delete Me Bank');
    await page.fill('input[name="bank_account[currency]"]', 'USD');
    await page.locator('select[name="bank_account[account_type]"]').selectOption('operating');
    await page.fill('input[name="bank_account[balance]"]', '100');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Bank account added');
    await expect(page.locator('body')).toContainText('E2E Delete Me Bank');

    // Now delete it - use the last delete button (the one we just created)
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Bank account deleted');
  });

  test('create a cash pool', async ({ page }) => {
    await page.goto('/bank-accounts');

    await page.locator('[phx-click="show_pool_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="pool[name]"]', 'E2E Test Pool');
    await page.fill('input[name="pool[currency]"]', 'USD');
    await page.fill('input[name="pool[target_balance]"]', '1000000');
    await page.fill('textarea[name="pool[notes]"]', 'Created by E2E test');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Cash pool added');
    await expect(page.locator('body')).toContainText('E2E Test Pool');
  });

  test('navigate to bank account detail page', async ({ page }) => {
    await page.goto('/bank-accounts');

    // Click on the first bank account link to go to the show page
    const firstLink = page.locator('a[href^="/bank-accounts/"]').first();
    await expect(firstLink).toBeVisible();
    const href = await firstLink.getAttribute('href');
    await firstLink.click();
    await page.waitForURL(href!);

    // Verify the detail page shows relevant information
    await expect(page.locator('body')).toContainText('Balance');
    await expect(page.locator('body')).toContainText('Currency');
    await expect(page.locator('body')).toContainText('Account Type');
  });
});

test.describe('Transactions', () => {
  test('list page loads with seeded data', async ({ page }) => {
    await page.goto('/transactions');
    await expect(page.locator('body')).toContainText('Transaction');
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('create a new transaction with all fields', async ({ page }) => {
    await page.goto('/transactions');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="transaction[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="transaction[date]"]', '2026-01-15');
    await page.fill('input[name="transaction[transaction_type]"]', 'wire_transfer');
    await page.fill('input[name="transaction[amount]"]', '75000.25');
    await page.fill('input[name="transaction[currency]"]', 'USD');
    await page.fill('input[name="transaction[description]"]', 'E2E test wire transfer');
    await page.fill('input[name="transaction[counterparty]"]', 'E2E Counterparty Inc.');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Transaction added');
    await expect(page.locator('body')).toContainText('E2E test wire transfer');
  });

  test('navigate to transaction detail page', async ({ page }) => {
    await page.goto('/transactions');

    const firstLink = page.locator('a[href^="/transactions/"]').first();
    await expect(firstLink).toBeVisible();
    const href = await firstLink.getAttribute('href');
    await firstLink.click();
    await page.waitForURL(href!);

    // Verify the detail page renders
    await expect(page.locator('body')).toContainText('Transaction');
  });

  test('edit a transaction', async ({ page }) => {
    await page.goto('/transactions');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="transaction[description]"]', 'E2E updated description');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Transaction updated');
    await expect(page.locator('body')).toContainText('E2E updated description');
  });

  test('delete a transaction', async ({ page }) => {
    await page.goto('/transactions');

    // First create one to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="transaction[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="transaction[date]"]', '2026-02-01');
    await page.fill('input[name="transaction[transaction_type]"]', 'fee');
    await page.fill('input[name="transaction[amount]"]', '99.99');
    await page.fill('input[name="transaction[currency]"]', 'USD');
    await page.fill('input[name="transaction[description]"]', 'E2E delete me transaction');
    await page.fill('input[name="transaction[counterparty]"]', 'Delete Corp');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Transaction added');
    await expect(page.locator('body')).toContainText('E2E delete me transaction');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Transaction deleted');
  });
});

test.describe('Aging Report', () => {
  test('page loads and displays report', async ({ page }) => {
    await page.goto('/aging');
    await expect(page.locator('body')).toContainText('Aging');
    // The aging report uses charts
    const canvas = page.locator('canvas');
    if (await canvas.count() > 0) {
      await expect(canvas.first()).toBeVisible();
    }
  });
});
