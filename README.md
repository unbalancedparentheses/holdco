# Holdco

Open-source holding company management system built on Elixir, Phoenix, and LiveView.

If you run a holding company, family office, or any multi-entity corporate
group, you need to track which companies you own, how they relate to each
other, what assets they hold, where those assets are custodied, what tax
deadlines are coming up, and what the financials look like across the whole
structure. Holdco does all of that in a single self-hosted application backed
by SQLite.

No SaaS, no vendor lock-in, no subscription. You own your data. Everything
runs locally or on your own server. The database is a single `.db` file you
can back up, copy, or move anywhere.

## What It Does

**Portfolio dashboard with NAV.** See total wealth at a glance — liquid assets
(bank balances), marketable assets (stocks and crypto with live prices),
illiquid assets (real estate, private equity with manual valuations), minus
liabilities = Net Asset Value. Breakdown by asset type and per company.
Interactive Chart.js charts for allocation, NAV history, and P&L trends.

**Corporate structure management.** Model your entire holding company tree —
parent companies, subsidiaries, ownership percentages, shareholders, directors,
lawyers, tax IDs, and notes. Supports any depth of nesting.

**Asset holdings and custody.** Track what each entity owns — equities, crypto,
commodities, real estate, private equity, or any custom asset. Record
quantities, tickers, currencies, asset types, and link each holding to a
custodian account with bank name, account number, type, and authorized persons.

**Live price tracking.** Fetches real-time prices from Yahoo Finance for any
ticker (including BTC, ETH, gold, silver, and forex pairs). Records price
history snapshots via Oban background jobs.

**Real-time audit log via PubSub.** Every create, update, and delete across all
tables is logged and streamed in real-time to the audit log page via Phoenix
PubSub — no page refresh required.

**Bank accounts.** Track bank accounts per entity — operating, savings, FX,
custody, and escrow accounts. Record bank name, account number, IBAN, SWIFT/BIC,
currency, balance, and authorized signers.

**Transaction history.** Record buy/sell transactions, dividends, fees,
distributions, and capital calls per entity. Track amount, currency,
counterparty, date, and link to asset holdings.

**Liabilities.** Track debt obligations per entity — bank loans, bonds, credit
lines, leases, and intercompany loans. Record principal, interest rate, maturity
date, and status.

**Document storage.** Attach contracts, articles of incorporation, tax filings,
and agreements to any company. Track document type, URL/path, notes, versions,
and upload date.

**Tax calendar.** Track tax filing deadlines per company and jurisdiction with
status tracking (pending, in progress, completed). Dashboard shows upcoming
deadlines at a glance. Automated reminders via Oban background jobs.

**Financial tracking.** Record revenue and expenses per entity per period with
multi-currency support. Dashboard aggregates totals and shows net P&L with
interactive bar charts.

**Governance.** Board meeting scheduling and tracking, cap table management,
shareholder resolutions, powers of attorney, equity incentive plans and grants,
M&A deal pipeline, joint venture tracking, and investor access controls.

**Compliance.** Regulatory filings and licenses, insurance policies, compliance
checklists, transfer pricing documentation, withholding taxes, FATCA reports,
ESG scores, and sanctions screening.

**Scenario modeling.** Create financial scenarios with revenue and expense
projections. Configure growth rates (linear or compound), recurrence, and
probability. View monthly projections with interactive charts.

**Settings and categories.** Define your own categories with custom colors.
Manage webhooks, backup configurations, and application settings.

**Role-based access control.** Three roles — admin (full access), editor (create
and update), viewer (read-only). Authentication via magic link email.

## Architecture

| Component | Technology |
|---|---|
| Web framework | Phoenix 1.8 |
| UI | Phoenix LiveView 1.1 |
| Database | SQLite via ecto_sqlite3 |
| Authentication | phx.gen.auth (magic link) |
| Background jobs | Oban |
| Price data | Yahoo Finance via Req |
| Live updates | Phoenix PubSub |
| Charts | Chart.js via LiveView hooks |
| CSS | Custom FT-inspired design system |

### Project Structure

| File / Directory | Purpose |
|---|---|
| `lib/holdco/` | Business logic — 14 bounded contexts with Ecto schemas |
| `lib/holdco/accounts/` | User, UserRole, ApiKey, authentication |
| `lib/holdco/corporate/` | Company tree, beneficial owners, key personnel, service providers |
| `lib/holdco/governance/` | Board meetings, cap table, resolutions, equity plans, deals |
| `lib/holdco/assets/` | Holdings, custodian accounts, cost basis lots, crypto wallets, real estate |
| `lib/holdco/banking/` | Bank accounts, transactions |
| `lib/holdco/finance/` | Financials, chart of accounts, journal entries, dividends, budgets, liabilities |
| `lib/holdco/compliance/` | Tax deadlines, regulatory filings, insurance, sanctions, ESG |
| `lib/holdco/documents/` | Documents, versions, uploads |
| `lib/holdco/treasury/` | Cash pools |
| `lib/holdco/pricing/` | Price history, Yahoo Finance client with ETS cache |
| `lib/holdco/platform/` | Settings, categories, audit log, webhooks, backups |
| `lib/holdco/integrations/` | Accounting sync, bank feeds, e-signatures, email digests |
| `lib/holdco/scenarios/` | Scenario modeling with projection engine |
| `lib/holdco/portfolio.ex` | NAV calculation, asset allocation, FX exposure |
| `lib/holdco/workers/` | Oban workers (price snapshots, portfolio snapshots, tax reminders) |
| `lib/holdco_web/live/` | 15 LiveView modules for all pages |
| `lib/holdco_web/components/` | Layout, FT design system, Chart.js hook |
| `lib/holdco_web/router.ex` | All routes |
| `assets/css/ft.css` | FT-inspired design system (warm ivory, teal, serif typography) |
| `assets/js/hooks/chart.js` | Chart.js LiveView hook |
| `priv/repo/migrations/` | Ecto migrations (74 tables) |
| `priv/repo/seeds.exs` | Seed data |

### LiveView Pages

| Route | Page | Description |
|---|---|---|
| `/` | Dashboard | NAV, metrics, charts, recent activity, audit feed |
| `/companies` | Companies | Company list with tree view, create form |
| `/companies/:id` | Company Detail | Tabbed view: holdings, bank accounts, transactions, documents, governance, compliance, financials |
| `/holdings` | Holdings | All holdings with allocation charts |
| `/transactions` | Transactions | Transaction list with inflow/outflow summary |
| `/bank-accounts` | Bank Accounts | Accounts with balances, currency breakdown |
| `/documents` | Documents | Document library |
| `/tax-calendar` | Tax Calendar | Deadlines, annual filings, compliance |
| `/financials` | Financials | P&L with trend charts, budgets |
| `/governance` | Governance | Board meetings, cap table, resolutions, equity plans |
| `/compliance` | Compliance | Regulatory filings, licenses, insurance, sanctions, ESG |
| `/scenarios` | Scenarios | Scenario list with create form |
| `/scenarios/:id` | Scenario Detail | Revenue/expense items, projection charts |
| `/audit-log` | Audit Log | Real-time audit stream via PubSub |
| `/settings` | Settings | App settings, categories, webhooks, backups |

## Quickstart

```bash
git clone https://github.com/unbalancedparentheses/holdco.git
cd holdco
mix setup                    # install deps, create DB, run migrations
mix run priv/repo/seeds.exs  # load example data
mix phx.server               # http://localhost:4000
```

Register a new account at `/users/register`, then log in.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SECRET_KEY_BASE` | dev key | Production secret key (min 64 bytes) |
| `DATABASE_PATH` | `holdco.db` | Path to SQLite database file |
| `PHX_HOST` | `localhost` | Production hostname |
| `PORT` | `4000` | HTTP port |

## Testing

```bash
mix test                     # run full suite
mix test --trace             # verbose output
```

## License

MIT
