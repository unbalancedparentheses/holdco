import { test, expect } from '@playwright/test';

test.describe('Contacts', () => {
  test('list page loads', async ({ page }) => {
    await page.goto('/contacts');
    await expect(page.locator('body')).toContainText('Contact');
  });

  test('create a new contact with all fields', async ({ page }) => {
    await page.goto('/contacts');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="contact[name]"]', 'E2E Test Contact');
    await page.fill('input[name="contact[title]"]', 'Chief Technology Officer');
    await page.fill('input[name="contact[organization]"]', 'E2E Corp');
    await page.fill('input[name="contact[email]"]', 'e2e@testcorp.com');
    await page.fill('input[name="contact[phone]"]', '+1-555-123-4567');
    await page.locator('select[name="contact[role_tag]"]').selectOption({ index: 1 });
    await page.fill('textarea[name="contact[notes]"]', 'Created by E2E test suite');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Contact created');
    await expect(page.locator('body')).toContainText('E2E Test Contact');
  });

  test('edit a contact', async ({ page }) => {
    await page.goto('/contacts');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="contact[name]"]', 'E2E Updated Contact');
    await page.fill('input[name="contact[title]"]', 'Chief Executive Officer');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Contact updated');
    await expect(page.locator('body')).toContainText('E2E Updated Contact');
  });

  test('delete a contact', async ({ page }) => {
    await page.goto('/contacts');

    // First create a contact to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="contact[name]"]', 'E2E Delete Me Contact');
    await page.fill('input[name="contact[email]"]', 'delete@testcorp.com');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Contact created');
    await expect(page.locator('body')).toContainText('E2E Delete Me Contact');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Contact deleted');
  });
});

test.describe('Projects', () => {
  test('list page loads', async ({ page }) => {
    await page.goto('/projects');
    await expect(page.locator('body')).toContainText('Project');
  });

  test('create a new project with all fields', async ({ page }) => {
    await page.goto('/projects');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="project[name]"]', 'E2E Test Project');
    await page.locator('select[name="project[status]"]').selectOption({ index: 1 });
    await page.locator('select[name="project[project_type]"]').selectOption({ index: 1 });
    await page.fill('textarea[name="project[description]"]', 'Project created by E2E test suite');
    await page.fill('input[name="project[start_date]"]', '2026-01-01');
    await page.fill('input[name="project[target_date]"]', '2026-12-31');
    await page.fill('input[name="project[budget]"]', '500000');
    await page.fill('input[name="project[currency]"]', 'USD');

    const contactSelect = page.locator('select[name="project[contact_id]"]');
    if (await contactSelect.isVisible()) {
      const optionCount = await contactSelect.locator('option').count();
      if (optionCount > 1) {
        await contactSelect.selectOption({ index: 1 });
      }
    }

    await page.fill('textarea[name="project[notes]"]', 'E2E test project notes');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Project created');
    await expect(page.locator('body')).toContainText('E2E Test Project');
  });

  test('filter projects by status', async ({ page }) => {
    await page.goto('/projects');

    // Click a specific status filter button
    const activeFilter = page.locator('[phx-click="filter_status"][phx-value-status="active"]');
    if (await activeFilter.isVisible()) {
      await activeFilter.click();
      await expect(page.locator('body')).toContainText('Project');
    }

    // Click "All" to reset filter
    const allFilter = page.locator('[phx-click="filter_status"][phx-value-status=""]');
    if (await allFilter.isVisible()) {
      await allFilter.click();
      await expect(page.locator('body')).toContainText('Project');
    }
  });

  test('edit a project', async ({ page }) => {
    await page.goto('/projects');

    await page.locator('[phx-click="edit"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="project[name]"]', 'E2E Updated Project');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Project updated');
    await expect(page.locator('body')).toContainText('E2E Updated Project');
  });

  test('delete a project', async ({ page }) => {
    await page.goto('/projects');

    // First create a project to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="project[name]"]', 'E2E Delete Me Project');
    await page.locator('select[name="project[status]"]').selectOption({ index: 1 });
    await page.locator('select[name="project[project_type]"]').selectOption({ index: 1 });
    await page.fill('input[name="project[budget]"]', '100');
    await page.fill('input[name="project[currency]"]', 'USD');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Project created');
    await expect(page.locator('body')).toContainText('E2E Delete Me Project');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Project deleted');
  });
});

test.describe('Scenarios', () => {
  test('list page loads', async ({ page }) => {
    await page.goto('/scenarios');
    await expect(page.locator('body')).toContainText('Scenario');
  });

  test('create a new scenario with all fields', async ({ page }) => {
    await page.goto('/scenarios');

    // The Scenarios index uses a <.link navigate> to /scenarios/new, not phx-click="show_form"
    await page.locator('a[href="/scenarios/new"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="scenario[name]"]', 'E2E Test Scenario');
    await page.fill('textarea[name="scenario[description]"]', 'Scenario created by E2E test suite');

    const companySelect = page.locator('select[name="scenario[company_id]"]');
    if (await companySelect.isVisible()) {
      const optionCount = await companySelect.locator('option').count();
      if (optionCount > 1) {
        await companySelect.selectOption({ index: 1 });
      }
    }

    await page.fill('input[name="scenario[projection_months]"]', '24');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Scenario created');
    await expect(page.locator('body')).toContainText('E2E Test Scenario');
  });

  test('navigate to scenario detail and add an item', async ({ page }) => {
    await page.goto('/scenarios');

    // Create a scenario to work with
    await page.locator('a[href="/scenarios/new"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="scenario[name]"]', 'E2E Detail Scenario');
    await page.fill('textarea[name="scenario[description]"]', 'Scenario for detail test');
    await page.fill('input[name="scenario[projection_months]"]', '12');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Scenario created');

    // Navigate to the scenario detail page via the table link
    const scenarioLink = page.locator('a.td-link', { hasText: 'E2E Detail Scenario' }).first();
    await scenarioLink.click();
    await page.waitForURL(/\/scenarios\/\d+/);

    // Verify the detail page loaded
    await expect(page.locator('body')).toContainText('E2E Detail Scenario');

    // Add an item to the scenario (show page uses phx-click="show_form")
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="item[name]"]', 'E2E Revenue Stream');
    await page.locator('select[name="item[item_type]"]').selectOption({ index: 1 });
    await page.fill('input[name="item[amount]"]', '100000');
    await page.fill('input[name="item[currency]"]', 'USD');
    await page.fill('input[name="item[growth_rate]"]', '5.5');
    await page.locator('select[name="item[growth_type]"]').selectOption({ index: 1 });
    await page.locator('select[name="item[recurrence]"]').selectOption({ index: 1 });
    await page.fill('input[name="item[probability]"]', '0.85');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('E2E Revenue Stream');
  });

  test('delete an item from a scenario', async ({ page }) => {
    await page.goto('/scenarios');

    // Create a scenario with an item to delete
    await page.locator('a[href="/scenarios/new"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="scenario[name]"]', 'E2E Item Delete Scenario');
    await page.fill('input[name="scenario[projection_months]"]', '6');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Scenario created');

    // Navigate to the scenario detail page
    const scenarioLink = page.locator('a.td-link', { hasText: 'E2E Item Delete Scenario' }).first();
    await scenarioLink.click();
    await page.waitForURL(/\/scenarios\/\d+/);

    // Add an item (show page uses phx-click="show_form")
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="item[name]"]', 'E2E Delete Me Item');
    await page.locator('select[name="item[item_type]"]').selectOption({ index: 1 });
    await page.fill('input[name="item[amount]"]', '50000');
    await page.fill('input[name="item[currency]"]', 'USD');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('E2E Delete Me Item');

    // Delete the item
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete_item"]').last().click();
    await expect(page.locator('body')).not.toContainText('E2E Delete Me Item');
  });

  test('delete a scenario', async ({ page }) => {
    await page.goto('/scenarios');

    // First create a scenario to safely delete
    await page.locator('a[href="/scenarios/new"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('input[name="scenario[name]"]', 'E2E Delete Me Scenario');
    await page.fill('input[name="scenario[projection_months]"]', '3');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Scenario created');
    await expect(page.locator('body')).toContainText('E2E Delete Me Scenario');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete"]').last().click();
    await expect(page.locator('body')).toContainText('Scenario deleted');
  });
});
