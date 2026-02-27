import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  test('registration page loads', async ({ page }) => {
    await page.goto('/users/register');
    await expect(page.locator('h2')).toContainText('Create an account');
    await expect(page.locator('input[name="user[email]"]')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('register a new user', async ({ page }) => {
    await page.goto('/users/register');
    const email = `e2e-${Date.now()}@test.local`;
    await page.fill('input[name="user[email]"]', email);
    await page.click('button[type="submit"]');
    // Should redirect to login with info flash
    await page.waitForURL(/\/users\/log-in/);
    await expect(page.locator('body')).toContainText('log');
  });

  test('login page loads with both forms', async ({ page }) => {
    await page.goto('/users/log-in');
    await expect(page.locator('h2')).toContainText('Log in');
    // Magic link form
    await expect(page.locator('#login_form_magic')).toBeVisible();
    // Password form
    await expect(page.locator('#login_form_password')).toBeVisible();
  });

  test('login with email and password', async ({ page }) => {
    await page.goto('/users/log-in');
    const passwordForm = page.locator('#login_form_password');
    await passwordForm.locator('input[name="user[email]"]').fill('admin@holdco.local');
    await passwordForm.locator('input[name="user[password]"]').fill('admin1234567!');
    await passwordForm.locator('button[type="submit"]').first().click();
    await page.waitForURL('/');
    await expect(page.locator('body')).toBeVisible();
  });

  test('login with wrong password shows error', async ({ page }) => {
    await page.goto('/users/log-in');
    const passwordForm = page.locator('#login_form_password');
    await passwordForm.locator('input[name="user[email]"]').fill('admin@holdco.local');
    await passwordForm.locator('input[name="user[password]"]').fill('wrongpassword');
    await passwordForm.locator('button[type="submit"]').first().click();
    await expect(page.locator('body')).toContainText('Invalid');
  });

  test('unauthenticated user redirected to login', async ({ page }) => {
    await page.goto('/companies');
    await page.waitForURL(/\/users\/log-in/);
  });

  test('logout', async ({ page }) => {
    // First login
    await page.goto('/users/log-in');
    const passwordForm = page.locator('#login_form_password');
    await passwordForm.locator('input[name="user[email]"]').fill('admin@holdco.local');
    await passwordForm.locator('input[name="user[password]"]').fill('admin1234567!');
    await passwordForm.locator('button[type="submit"]').first().click();
    await page.waitForURL('/');

    // Now logout
    await page.locator('a[href="/users/log-out"]').click();
    // Confirm logout via form submission
    await page.waitForURL(/\/users\/log-in/);
  });
});
