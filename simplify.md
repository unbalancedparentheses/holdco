# Simplify Holdco — What We Keep vs Cut

## Context

5-10 person holding company managing multiple entities.
Not a fund. Uses QuickBooks per entity (no multi-entity support).
Accountants handle tax. Holds crypto/DeFi. Wants risk analytics.
Transfer pricing and contracts needed (multi-entity).

---

## KEEP (52 pages)

### Core (11)
- Dashboard
- Companies
- Positions
- Transactions
- Bank Accounts
- Financials
- Documents
- Contacts
- Calendar
- Org Chart
- Search

### Governance & Corporate (7)
- Governance
- Compliance
- Board Meetings
- Corporate Actions (dividends, share issues between entities)
- Registers (statutory shareholder/director registers — legally required)
- Share Classes (cap table — who owns what %)
- Related Party Transactions (intercompany disclosure — legally required)

### Accounting (9)
QuickBooks can't consolidate across entities, so Holdco does multi-entity accounting.
- Chart of Accounts
- Journal Entries
- Accounting Reports
- Integrations (QuickBooks/Xero sync)
- Consolidated
- Bank Reconciliation
- Period Locks
- Recurring Transactions
- Budget Variance

### Tax (5)
Visibility only — accountants do the work. Transfer Pricing stays because multi-entity.
- Tax Provisions
- Deferred Taxes
- Capital Gains
- Tax Calendar
- Transfer Pricing

### Risk & Analytics (10)
- Concentration Risk
- Counterparty Risk
- Covenants
- Stress Testing
- Liquidity
- Debt Maturity
- Cash Forecast
- Anomalies
- Benchmarks
- Scenarios

### Crypto (1)
- DeFi Positions

### Reports (5)
Contracts moved here from Legal (cross-entity view).
- Reports overview
- KPIs
- Entity Comparison
- Scheduled Reports
- Contracts

### Admin (7)
- Settings
- Notification Settings
- Audit Log
- Approvals
- Notifications
- Alerts
- Import

---

## CUT (64 pages)

None of these are empty scaffolds — they all have working code (150-960 lines each).
We're cutting them because the features don't match the business, not because the code is bad.

### Fund Management (11) — not a fund
- Capital Calls (452 lines)
- Distributions (430 lines)
- Waterfall (644 lines)
- Fund NAV (298 lines)
- Investor Statements (365 lines)
- Fund Fees (410 lines)
- K-1 Reports (434 lines)
- Dividend Policies (363 lines)
- Fundraising (549 lines)
- Partnership Basis (445 lines)
- Investor Portal (358 lines)

### Legal (5) — no Legal dropdown needed
- AML Monitoring (381 lines)
- LEI Tracking (311 lines)
- Conflicts of Interest (328 lines)
- IP Assets (423 lines)
- Ethics (284 lines)

### Legal — moved to cut after review (4)
- Litigation (320 lines)
- Insurance Claims (310 lines)
- Bank Guarantees (332 lines)
- KYC (387 lines)

### Family Office (4) — not a family office
- Trusts (459 lines)
- Charitable Giving (295 lines)
- Family Governance (471 lines)
- Estate Planning (475 lines)

### Corporate bloat (5) — don't earn a standalone page
- Entity Lifecycle (310 lines)
- Shareholder Communications (360 lines)
- Signatures (412 lines)
- Projects (727 lines)
- Compensation (321 lines)
- Data Room (296 lines)

### Accounting (4) — per-entity work, stays in QuickBooks
- Depreciation (518 lines)
- Revaluation (404 lines)
- Goodwill (531 lines)
- Multi-Book (631 lines)

### Tax (3) — accountants handle it
- Tax Optimizer (373 lines)
- Withholding Reclaims (362 lines)
- Repatriation (347 lines)

### Risk (5) — not needed for this business
- ESG (245 lines)
- Emissions (262 lines)
- Regulatory Capital (262 lines)
- Regulatory Changes (283 lines)
- BCP (299 lines)

### Reports (6) — duplicates or too niche
- Aging (261 lines)
- Management Reports (967 lines)
- Audit Diffs (341 lines)
- Reporting Templates (283 lines)
- Health Score (339 lines)
- Data Lineage (291 lines)

### Admin (14) — enterprise bloat for a 5-10 person team
- Tasks (490 lines)
- Bulk Edit (365 lines)
- Activity (145 lines)
- Collaboration (160 lines)
- Document Intelligence (244 lines)
- Quick Actions (290 lines)
- SSO Config (229 lines)
- Security Keys (152 lines)
- Data Retention (355 lines)
- Notification Channels (276 lines)
- BI Connectors (295 lines)
- White Label (236 lines)
- Custom Dashboards (223 lines)
- Plugins (348 lines)
- Webhooks (316 lines)

### Other (1)
- Airdrops (310 lines)

---

## Notes

- Only UI files (LiveView pages) are deleted
- All schemas, migrations, and context functions stay
- Contracts moves from deleted Legal dropdown into Reports
- Related Party Transactions, Corporate Actions, Share Classes, Registers move into Governance & Corporate
- Notification Settings stays in Admin
- Backend code for cut features remains available if we ever want to re-add UI
