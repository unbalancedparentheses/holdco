import { test, expect } from '@playwright/test';

// ---------------------------------------------------------------------------
// 1. CSV Downloads
// ---------------------------------------------------------------------------
test.describe('CSV Downloads', () => {
  test('download companies CSV', async ({ page }) => {
    await page.goto('/companies');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/companies.csv"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('download holdings CSV', async ({ page }) => {
    await page.goto('/holdings');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/holdings.csv"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('download transactions CSV', async ({ page }) => {
    await page.goto('/transactions');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/transactions.csv"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('download chart of accounts CSV', async ({ page }) => {
    await page.goto('/accounts/chart');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/chart-of-accounts.csv"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('download journal entries CSV', async ({ page }) => {
    await page.goto('/accounts/journal');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/journal-entries.csv"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('download audit log CSV', async ({ page }) => {
    await page.goto('/audit-log');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/audit-log.csv"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.csv');
  });

  test('download audit package ZIP', async ({ page }) => {
    await page.goto('/audit-log');
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('a[href="/export/audit-package.zip"]').click(),
    ]);
    expect(download.suggestedFilename()).toContain('.zip');
  });
});

// ---------------------------------------------------------------------------
// 2. Audit Diffs Page
// ---------------------------------------------------------------------------
test.describe('Audit Diffs', () => {
  test('loads and displays audit diffs page', async ({ page }) => {
    await page.goto('/audit-diffs');
    await expect(page.locator('body')).toContainText('Audit');
  });
});

// ---------------------------------------------------------------------------
// 3. Audit Log Page
// ---------------------------------------------------------------------------
test.describe('Audit Log', () => {
  test('loads and shows seeded audit entries', async ({ page }) => {
    await page.goto('/audit-log');
    await expect(page.locator('body')).toContainText('Audit');
    // Seeded data should produce at least one audit log entry
    const rows = page.locator('table tbody tr');
    await expect(rows.first()).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// 4. Import Page
// ---------------------------------------------------------------------------
test.describe('Import Page', () => {
  test('loads the import page', async ({ page }) => {
    await page.goto('/import');
    await expect(page.locator('body')).toContainText('Import');
  });

  test('switch between import tabs', async ({ page }) => {
    await page.goto('/import');

    // Switch to Companies tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="companies"]').click();
    await expect(page.locator('body')).toContainText('Companies');

    // Switch to Holdings tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="holdings"]').click();
    await expect(page.locator('body')).toContainText('Holdings');

    // Switch to Transactions tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="transactions"]').click();
    await expect(page.locator('body')).toContainText('Transactions');
  });

  test('file upload input is present', async ({ page }) => {
    await page.goto('/import');
    const fileInput = page.locator('.live_file_input, input[type="file"]');
    await expect(fileInput.first()).toBeAttached();
  });
});

// ---------------------------------------------------------------------------
// 5. Search Page
// ---------------------------------------------------------------------------
test.describe('Search Page', () => {
  test('search for Acme and verify results', async ({ page }) => {
    await page.goto('/search');
    await expect(page.locator('body')).toContainText('Search');

    // Fill in the search form and submit
    await page.fill('input[name="q"]', 'Acme');
    await page.locator('form[phx-submit="search"] button[type="submit"]').click();

    // Verify results contain seeded Acme companies
    await expect(page.locator('body')).toContainText('Acme');
  });
});

// ---------------------------------------------------------------------------
// 6. Notifications Page
// ---------------------------------------------------------------------------
test.describe('Notifications Page', () => {
  test('loads the notifications page', async ({ page }) => {
    await page.goto('/notifications');
    await expect(page.locator('body')).toContainText('Notification');
  });
});

// ---------------------------------------------------------------------------
// 7. Settings Page
// ---------------------------------------------------------------------------
test.describe('Settings Page', () => {
  test('loads the settings page', async ({ page }) => {
    await page.goto('/settings');
    await expect(page.locator('body')).toContainText('Settings');
  });

  test('create a setting in settings tab', async ({ page }) => {
    await page.goto('/settings');

    // Ensure we are on the settings tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="settings"]').click();

    // Fill in the setting form
    await page.fill('input[name="setting[key]"]', 'e2e_test_key');
    await page.fill('input[name="setting[value]"]', 'e2e_test_value');

    // Submit the form
    await page.locator('form[phx-submit="save_setting"] button[type="submit"]').click();

    // Verify the setting was saved
    await expect(page.locator('body')).toContainText('e2e_test_key');
    await expect(page.locator('body')).toContainText('e2e_test_value');
  });

  test('create a category in categories tab', async ({ page }) => {
    await page.goto('/settings');

    // Switch to categories tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="categories"]').click();

    // Fill in the category form
    await page.fill('input[name="category[name]"]', 'E2E Test Category');
    await page.locator('input[name="category[color]"]').fill('#ff5733');

    // Submit the form
    await page.locator('form[phx-submit="save_category"] button[type="submit"]').click();

    // Verify the category was saved
    await expect(page.locator('body')).toContainText('E2E Test Category');
  });

  test('create a webhook in webhooks tab', async ({ page }) => {
    await page.goto('/settings');

    // Switch to webhooks tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="webhooks"]').click();

    // Fill in the webhook form
    await page.fill('input[name="webhook[url]"]', 'https://hooks.example.com/e2e-test');
    await page.fill('input[name="webhook[events]"]', 'company.created,transaction.created');
    await page.fill('input[name="webhook[secret]"]', 'e2e_webhook_secret_123');
    await page.fill('textarea[name="webhook[notes]"]', 'Created by E2E test suite');

    // Submit the form
    await page.locator('form[phx-submit="save_webhook"] button[type="submit"]').click();

    // Verify the webhook was saved
    await expect(page.locator('body')).toContainText('https://hooks.example.com/e2e-test');
  });

  test('create a backup config in backups tab', async ({ page }) => {
    await page.goto('/settings');

    // Switch to backups tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="backups"]').click();

    // Fill in the backup config form
    await page.fill('input[name="backup_config[name]"]', 'E2E Nightly Backup');

    const destinationTypeSelect = page.locator('select[name="backup_config[destination_type]"]');
    await destinationTypeSelect.selectOption({ index: 1 });

    await page.fill('input[name="backup_config[destination_path]"]', '/backups/e2e-test');

    const scheduleSelect = page.locator('select[name="backup_config[schedule]"]');
    await scheduleSelect.selectOption({ index: 1 });

    await page.fill('input[name="backup_config[retention_days]"]', '30');

    // Submit the form
    await page.locator('form[phx-submit="save_backup"] button[type="submit"]').click();

    // Verify the backup config was saved
    await expect(page.locator('body')).toContainText('E2E Nightly Backup');
  });

  test('users tab shows user list', async ({ page }) => {
    await page.goto('/settings');

    // Switch to users tab
    await page.locator('[phx-click="switch_tab"][phx-value-tab="users"]').click();

    // Verify user list is visible with at least one user and a role select
    const roleSelect = page.locator('select').first();
    await expect(roleSelect).toBeVisible();
  });
});
