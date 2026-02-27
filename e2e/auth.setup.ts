import { test as setup, expect } from '@playwright/test';

setup('authenticate', async ({ page, context }) => {
  // Clear any existing cookies so we start fresh
  await context.clearCookies();

  // Log in with the seeded admin user via password form
  await page.goto('/users/log-in');

  // Page may show "Log in" or "Re-authenticate" depending on state
  await expect(page.locator('h2')).toBeVisible();

  // Fill the password login form (second form on the page)
  const passwordForm = page.locator('#login_form_password');
  await passwordForm.locator('input[name="user[email]"]').fill('admin@holdco.local');
  await passwordForm.locator('input[name="user[password]"]').fill('admin1234567!');
  await passwordForm.locator('button[type="submit"]').first().click();

  // Should redirect to dashboard
  await page.waitForURL('/', { timeout: 10_000 });
  await expect(page.locator('body')).toBeVisible();

  // Save auth state for reuse in all tests
  await page.context().storageState({ path: 'e2e/.auth/user.json' });
});
