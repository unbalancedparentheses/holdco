import { test, expect } from '@playwright/test';

test.describe('Documents List (/documents)', () => {
  test('loads and displays seeded documents', async ({ page }) => {
    await page.goto('/documents');
    await expect(page.locator('body')).toContainText('Document');

    // Verify seeded documents are visible in the table
    const body = page.locator('body');
    await expect(body).toContainText('Certificate of Incorporation');
    await expect(body).toContainText('Shareholder Agreement 2024');
    await expect(body).toContainText('Software License Agreement - AWS');

    // Verify table columns
    await expect(page.locator('table').first()).toBeVisible();
  });

  test('filter documents by company', async ({ page }) => {
    await page.goto('/documents');

    const companyFilter = page.locator(
      'form[phx-change="filter_company"] select[name="company_id"]'
    );
    await expect(companyFilter).toBeVisible();

    // Select a specific company (index 0 is "All Companies")
    await companyFilter.selectOption({ index: 1 });

    // Page should still render without error after filtering
    await expect(page.locator('body')).toContainText('Document');
    await expect(page.locator('table').first()).toBeVisible();

    // Reset filter to All Companies
    await companyFilter.selectOption('');
    await expect(page.locator('body')).toContainText('Certificate of Incorporation');
  });

  test('create a new document', async ({ page }) => {
    await page.goto('/documents');

    // Open the Add Document modal
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Fill in all metadata fields
    await page.locator('.dialog-panel select[name="document[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="document[name]"]', 'E2E Test Document');
    await page.fill('.dialog-panel input[name="document[doc_type]"]', 'contract');
    await page.fill('.dialog-panel input[name="document[url]"]', 'https://docs.example.com/e2e-test.pdf');
    await page.fill('.dialog-panel textarea[name="document[notes]"]', 'Created by E2E test suite');

    // Submit the form (skip file upload, just test metadata fields)
    await page.locator('.dialog-panel button[type="submit"]').click();

    // Verify flash message and new document appears
    await expect(page.locator('body')).toContainText('Document added');
    await expect(page.locator('body')).toContainText('E2E Test Document');
  });

  test('edit an existing document', async ({ page }) => {
    await page.goto('/documents');

    // First create a document to edit
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('.dialog-panel select[name="document[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="document[name]"]', 'Edit Target Document');
    await page.fill('.dialog-panel input[name="document[doc_type]"]', 'report');
    await page.fill('.dialog-panel input[name="document[url]"]', 'https://docs.example.com/edit-target.pdf');
    await page.fill('.dialog-panel textarea[name="document[notes]"]', 'Will be edited');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Document added');
    await expect(page.locator('body')).toContainText('Edit Target Document');

    // Now find the row and click Edit
    const row = page.locator('tr', { hasText: 'Edit Target Document' });
    await row.locator('[phx-click="edit"]').click();
    await page.locator('.dialog-panel').waitFor();

    // Change the document name
    await page.fill('.dialog-panel input[name="document[name]"]', 'Edited Document Name');

    // Submit the update
    await page.locator('.dialog-panel button[type="submit"]').click();

    // Verify flash message and updated name
    await expect(page.locator('body')).toContainText('Document updated');
    await expect(page.locator('body')).toContainText('Edited Document Name');
  });

  test('delete a document', async ({ page }) => {
    await page.goto('/documents');

    // First create a document to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('.dialog-panel select[name="document[company_id]"]').selectOption({ index: 1 });
    await page.fill('.dialog-panel input[name="document[name]"]', 'E2E Delete Me Document');
    await page.fill('.dialog-panel input[name="document[doc_type]"]', 'certificate');
    await page.fill('.dialog-panel textarea[name="document[notes]"]', 'This will be deleted');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Document added');
    await expect(page.locator('body')).toContainText('E2E Delete Me Document');

    // Accept the confirmation dialog before clicking delete
    page.on('dialog', (dialog) => dialog.accept());

    // Find the row and click delete
    const row = page.locator('tr', { hasText: 'E2E Delete Me Document' });
    await row.locator('[phx-click="delete"]').click();

    // Verify flash message and document is gone
    await expect(page.locator('body')).toContainText('Document deleted');
    await expect(page.locator('body')).not.toContainText('E2E Delete Me Document');
  });
});
