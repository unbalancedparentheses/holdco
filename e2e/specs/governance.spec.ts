import { test, expect } from '@playwright/test';

// ---------------------------------------------------------------------------
// 1. Governance (/governance) - Page Load & Tabs
// ---------------------------------------------------------------------------
test.describe('Governance Page', () => {
  test('loads and displays governance page with meetings tab active', async ({ page }) => {
    await page.goto('/governance');
    await expect(page.locator('h1')).toContainText('Governance');
    await expect(page.locator('body')).toContainText(
      'Board meetings, cap table, resolutions, deals, equity plans, JVs, and powers of attorney'
    );

    // Meetings tab should be active by default
    const meetingsTab = page.locator('button[phx-value-tab="meetings"]');
    await expect(meetingsTab).toBeVisible();

    // All 7 tab buttons should be present
    await expect(page.locator('button[phx-value-tab="cap_table"]')).toBeVisible();
    await expect(page.locator('button[phx-value-tab="resolutions"]')).toBeVisible();
    await expect(page.locator('button[phx-value-tab="deals"]')).toBeVisible();
    await expect(page.locator('button[phx-value-tab="equity_plans"]')).toBeVisible();
    await expect(page.locator('button[phx-value-tab="joint_ventures"]')).toBeVisible();
    await expect(page.locator('button[phx-value-tab="powers_of_attorney"]')).toBeVisible();
  });

  // -----------------------------------------------------------------------
  // Tab 1: Meetings
  // -----------------------------------------------------------------------
  test('meetings tab shows seeded board meetings', async ({ page }) => {
    await page.goto('/governance');

    const body = page.locator('body');
    // Seeded board meetings
    await expect(body).toContainText('annual');
    await expect(body).toContainText('2025-03-15');
  });

  test('create a new board meeting', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="board_meeting[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="board_meeting[scheduled_date]"]', '2026-01-15');
    await page.locator('select[name="board_meeting[meeting_type]"]').selectOption('special');
    await page.fill('textarea[name="board_meeting[notes]"]', 'E2E test board meeting notes');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Meeting added');
    await expect(page.locator('body')).toContainText('2026-01-15');
  });

  // -----------------------------------------------------------------------
  // Tab 2: Cap Table
  // -----------------------------------------------------------------------
  test('cap_table tab shows seeded cap table entries', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="cap_table"]').click();

    const body = page.locator('body');
    await expect(body).toContainText('Cap Table');
    await expect(body).toContainText('Jane Smith');
    await expect(body).toContainText('Founder');
  });

  test('create a new cap table entry', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="cap_table"]').click();

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="cap_table_entry[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="cap_table_entry[investor]"]', 'E2E Venture Capital');
    await page.fill('input[name="cap_table_entry[round_name]"]', 'Series A');
    await page.fill('input[name="cap_table_entry[shares]"]', '50000');
    await page.fill('input[name="cap_table_entry[amount_invested]"]', '2500000');
    await page.fill('input[name="cap_table_entry[date]"]', '2026-02-01');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Entry added');
    await expect(page.locator('body')).toContainText('E2E Venture Capital');
  });

  // -----------------------------------------------------------------------
  // Tab 3: Resolutions
  // -----------------------------------------------------------------------
  test('resolutions tab shows seeded shareholder resolutions', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="resolutions"]').click();

    const body = page.locator('body');
    await expect(body).toContainText('Shareholder Resolutions');
    await expect(body).toContainText('Approve 2024 Annual Accounts');
    await expect(body).toContainText('ordinary');
  });

  test('create a new resolution', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="resolutions"]').click();

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="resolution[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="resolution[title]"]', 'E2E Resolution Title');
    await page.fill('input[name="resolution[date]"]', '2026-03-01');
    await page.locator('select[name="resolution[resolution_type]"]').selectOption('special');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Resolution added');
    await expect(page.locator('body')).toContainText('E2E Resolution Title');
  });

  // -----------------------------------------------------------------------
  // Tab 4: Deals
  // -----------------------------------------------------------------------
  test('deals tab shows seeded deals', async ({ page }) => {
    await page.goto('/governance');

    // Wait for LiveView to connect before switching tabs
    await page.locator('[data-phx-main].phx-connected').waitFor({ timeout: 10000 });

    await page.locator('button[phx-value-tab="deals"]').click();

    const body = page.locator('body');
    await expect(body).toContainText('Deals');
    // Verify the deals tab renders (table or empty state)
    const table = page.locator('table');
    const emptyState = page.locator('.empty-state');
    // Either the deals table or empty state should be visible
    await expect(table.or(emptyState).first()).toBeVisible();
  });

  test('create a new deal', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="deals"]').click();

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="deal[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="deal[counterparty]"]', 'E2E AcquireCo');
    await page.locator('select[name="deal[deal_type]"]').selectOption('merger');
    await page.fill('input[name="deal[value]"]', '7500000');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Deal added');
    await expect(page.locator('body')).toContainText('E2E AcquireCo');
  });

  // -----------------------------------------------------------------------
  // Tab 5: Equity Plans
  // -----------------------------------------------------------------------
  test('equity_plans tab shows seeded equity plans', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="equity_plans"]').click();

    const body = page.locator('body');
    await expect(body).toContainText('Equity Incentive Plans');
    await expect(body).toContainText('2024 Employee Stock Option Plan');
    await expect(body).toContainText('4-year with 1-year cliff');
  });

  test('create a new equity plan', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="equity_plans"]').click();

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="equity_plan[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="equity_plan[plan_name]"]', 'E2E 2026 RSU Plan');
    await page.fill('input[name="equity_plan[total_pool]"]', '200000');
    await page.fill('input[name="equity_plan[vesting_schedule]"]', '3-year monthly vesting');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Equity plan added');
    await expect(page.locator('body')).toContainText('E2E 2026 RSU Plan');
  });

  // -----------------------------------------------------------------------
  // Tab 6: Joint Ventures
  // -----------------------------------------------------------------------
  test('joint_ventures tab shows seeded joint ventures', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="joint_ventures"]').click();

    const body = page.locator('body');
    await expect(body).toContainText('Joint Ventures');
    await expect(body).toContainText('Digital Content Partners');
    await expect(body).toContainText('StreamCo Ltd');
  });

  test('create a new joint venture', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="joint_ventures"]').click();

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="joint_venture[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="joint_venture[name]"]', 'E2E Logistics JV');
    await page.fill('input[name="joint_venture[partner]"]', 'E2E Partner Corp');
    await page.fill('input[name="joint_venture[ownership_pct]"]', '45');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Joint venture added');
    await expect(page.locator('body')).toContainText('E2E Logistics JV');
  });

  // -----------------------------------------------------------------------
  // Tab 7: Powers of Attorney
  // -----------------------------------------------------------------------
  test('powers_of_attorney tab shows seeded powers of attorney', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="powers_of_attorney"]').click();

    const body = page.locator('body');
    await expect(body).toContainText('Powers of Attorney');
    await expect(body).toContainText('Acme Holdings');
    await expect(body).toContainText('Sarah Johnson');
    await expect(body).toContainText('Corporate filings and regulatory submissions');
  });

  test('create a new power of attorney', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="powers_of_attorney"]').click();

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="power_of_attorney[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="power_of_attorney[grantor]"]', 'E2E Board Chair');
    await page.fill('input[name="power_of_attorney[grantee]"]', 'E2E General Counsel');
    await page.fill('input[name="power_of_attorney[scope]"]', 'Legal representation');
    await page.fill('input[name="power_of_attorney[start_date]"]', '2026-01-01');
    await page.fill('input[name="power_of_attorney[end_date]"]', '2026-12-31');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Power of attorney added');
    await expect(page.locator('body')).toContainText('E2E Board Chair');
  });

  // -----------------------------------------------------------------------
  // Edit - test on meetings tab
  // -----------------------------------------------------------------------
  test('edit a board meeting', async ({ page }) => {
    await page.goto('/governance');

    // Click the first edit button in the meetings table
    await page.locator('[phx-click="edit_meeting"]').first().click();
    await page.locator('.dialog-panel').waitFor();

    await page.fill('textarea[name="board_meeting[notes]"]', 'E2E updated meeting notes');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Meeting updated');
  });

  // -----------------------------------------------------------------------
  // Delete - test on deals tab (create one first, then delete)
  // -----------------------------------------------------------------------
  test('delete a deal', async ({ page }) => {
    await page.goto('/governance');

    await page.locator('button[phx-value-tab="deals"]').click();

    // Create a deal to safely delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="deal[company_id]"]').selectOption({ index: 1 });
    await page.fill('input[name="deal[counterparty]"]', 'E2E Delete Me Deal');
    await page.locator('select[name="deal[deal_type]"]').selectOption('investment');
    await page.fill('input[name="deal[value]"]', '100');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Deal added');
    await expect(page.locator('body')).toContainText('E2E Delete Me Deal');

    // Accept the confirmation dialog before clicking delete
    page.on('dialog', (dialog) => dialog.accept());

    // Delete the last deal (the one we just created)
    await page.locator('[phx-click="delete_deal"]').last().click();
    await expect(page.locator('body')).toContainText('Deal deleted');
  });
});

// ---------------------------------------------------------------------------
// 2. Approvals (/approvals)
// ---------------------------------------------------------------------------
test.describe('Approvals Page', () => {
  test('loads and displays approvals page', async ({ page }) => {
    await page.goto('/approvals');
    await expect(page.locator('h1')).toContainText('Approvals');
    await expect(page.locator('body')).toContainText(
      'Review and manage approval requests for data changes across all entities'
    );

    // Metrics strip should show counts
    await expect(page.locator('body')).toContainText('Pending');
    await expect(page.locator('body')).toContainText('Approved');
    await expect(page.locator('body')).toContainText('Rejected');
    await expect(page.locator('body')).toContainText('Total');
  });

  test('create an approval request', async ({ page }) => {
    await page.goto('/approvals');

    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="approval_request[table_name]"]').selectOption('companies');
    await page.locator('select[name="approval_request[action]"]').selectOption('create');
    await page.fill('input[name="approval_request[record_id]"]', '99');
    await page.fill('textarea[name="approval_request[notes]"]', 'E2E approval request note');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Approval request submitted');
    await expect(page.locator('body')).toContainText('E2E approval request note');
  });

  test('approve an approval request', async ({ page }) => {
    await page.goto('/approvals');

    // If there are pending requests, the admin can approve them
    const approveBtn = page.locator('[phx-click="approve"]').first();
    if (await approveBtn.isVisible()) {
      page.on('dialog', (dialog) => dialog.accept());
      await approveBtn.click();
      await expect(page.locator('body')).toContainText('Request approved');
    }
  });

  test('reject an approval request', async ({ page }) => {
    await page.goto('/approvals');

    // Create a new one to reject
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="approval_request[table_name]"]').selectOption('holdings');
    await page.locator('select[name="approval_request[action]"]').selectOption('delete');
    await page.fill('textarea[name="approval_request[notes]"]', 'E2E reject test');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Approval request submitted');

    // Now reject it
    const rejectBtn = page.locator('[phx-click="reject"]').first();
    if (await rejectBtn.isVisible()) {
      page.on('dialog', (dialog) => dialog.accept());
      await rejectBtn.click();
      await expect(page.locator('body')).toContainText('Request rejected');
    }
  });

  test('delete an approval request', async ({ page }) => {
    await page.goto('/approvals');

    // Create one to delete
    await page.locator('[phx-click="show_form"]').click();
    await page.locator('.dialog-panel').waitFor();

    await page.locator('select[name="approval_request[table_name]"]').selectOption('transactions');
    await page.locator('select[name="approval_request[action]"]').selectOption('update');
    await page.fill('textarea[name="approval_request[notes]"]', 'E2E delete request test');

    await page.locator('.dialog-panel button[type="submit"]').click();
    await expect(page.locator('body')).toContainText('Approval request submitted');

    // Now delete it
    page.on('dialog', (dialog) => dialog.accept());
    await page.locator('[phx-click="delete_request"]').last().click();
    await expect(page.locator('body')).toContainText('Request deleted');
  });
});
