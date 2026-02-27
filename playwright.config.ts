import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e/specs',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: 'list',
  timeout: 30_000,

  use: {
    baseURL: 'http://localhost:4002',
    storageState: 'e2e/.auth/user.json',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'setup',
      testDir: './e2e',
      testMatch: /auth\.setup\.ts/,
      use: { storageState: undefined },
    },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
    },
  ],

  webServer: {
    command: 'E2E=true MIX_ENV=test mix phx.server',
    url: 'http://localhost:4002/health',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
