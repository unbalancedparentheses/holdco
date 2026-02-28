# Holdco

Open-source holding company management system built on Elixir, Phoenix, and LiveView.

<!-- TODO: add screenshot of dashboard -->

If you run a holding company or any multi-entity corporate group, you need to
track which companies you own, how they relate to each other, what assets they
hold, where those assets are custodied, what tax deadlines are coming up, and
what the financials look like across the whole structure. Holdco does all of
that in a single self-hosted application backed by PostgreSQL.

No SaaS, no vendor lock-in, no subscription. You own your data. Everything
runs locally or on your own server.

## Features

**Portfolio dashboard.** Net Asset Value calculated from liquid assets (bank
balances), marketable assets (stocks and crypto with live prices), illiquid
assets (real estate, private equity), minus liabilities. Interactive Chart.js
charts for allocation and NAV history.

**Corporate structure.** Model your entire holding company tree with any depth
of nesting. Track ownership percentages, beneficial owners, key personnel,
service providers, and ownership changes per entity.

**Asset holdings and custody.** Equities, crypto, commodities, real estate,
private equity, or any custom asset type. Link each holding to a custodian
account with bank name, account number, and authorized persons. Cost basis lot
tracking for tax reporting.

**Live prices.** Yahoo Finance integration for any ticker (stocks, ETFs,
BTC-USD, GC=F, EURUSD=X). ETS-cached with configurable TTL. Price history
snapshots via Oban background jobs.

**Bank accounts.** Operating, savings, FX, custody, and escrow accounts per
entity. IBAN, SWIFT/BIC, currency, balance, and authorized signers.

**Transactions.** Buy/sell, dividends, fees, distributions, capital calls.
Amount, currency, counterparty, date, linked to holdings and bank accounts.

**Liabilities.** Bank loans, bonds, credit lines, intercompany loans.
Principal, interest rate, maturity date, currency, and status tracking.

**Financial tracking.** Revenue and expenses per entity per period with
multi-currency support. Inter-company transfers, dividends, capital
contributions, tax payments, and budgets.

**Double-entry accounting.** Full chart of accounts, journal entries with
balanced debit/credit lines, trial balance, balance sheet, and income
statement. All accounting data is entity-scoped: each company owns its own
accounts and journal entries, global pages show consolidated views with company
filter dropdowns. QuickBooks Online integration syncs accounts and journal
entries into a specific company.

**Consolidated financial statements.** Automatic elimination of intercompany
balances and transactions for group-level reporting.

**Governance.** Board meetings, corporate actions, statutory registers, share
classes, and related party transaction tracking.

**Compliance.** Regulatory filings, licenses, insurance policies, compliance
checklists, and transfer pricing documentation.

**Tax visibility.** Tax provisions, deferred taxes, capital gains tracking,
tax calendar with filing deadlines per company and jurisdiction, and transfer
pricing documentation for multi-entity structures.

**Risk analytics.** Concentration risk, counterparty risk scoring, covenant
monitoring, stress testing, liquidity coverage, debt maturity ladder, cash
flow forecasting, anomaly detection, and benchmarking.

**DeFi positions.** On-chain position tracking with value by chain and
protocol, automatic price fetching via CoinGecko.

**Contracts.** Cross-entity contract registry with expiry calendar,
counterparty concentration, and renewal alerts.

**Documents.** Contracts, articles of incorporation, tax filings, agreements.
Document versioning and file uploads per company.

**Scenario modeling.** Financial projections with linear or compound growth
rates, recurrence, and probability weighting. Monthly projection charts.

**Audit log.** Every create, update, and delete is logged and streamed in
real-time via Phoenix PubSub.

**Approval workflows.** Require N-of-M approvals for transactions above a
threshold, dividend declarations, or new entity creation.

**Role-based access control.** Three roles: admin (full access), editor
(create and update), viewer (read-only). Enforced at the LiveView level.
Authentication via email and password with optional TOTP two-factor
authentication.

**Notifications and alerts.** In-app notification center for system events,
deadline reminders, and approval requests. Configurable rule-based alerts.

**Settings.** User management, org config, preferences, API keys, and
notification settings. Admin-only.

**QuickBooks Online integration.** OAuth2 connection with automatic token
refresh. Sync chart of accounts and journal entries from QBO into a specific
company entity. Each subsidiary connects independently from its company detail
page; the global integrations page shows a summary dashboard of all connections.

**Automated backups.** Daily PostgreSQL `pg_dump` backups to a configured path
with retention-based cleanup. Backup logs visible in settings.

**Email digests.** Weekly email summaries including portfolio NAV, upcoming
deadlines, recent audit activity, and transactions. Configurable per user.

**Gains tracking.** Unrealized and realized gain/loss calculations per holding
based on cost basis lots. Aggregate portfolio-level gains.

**Dynamic FX rates.** Live currency conversion via Yahoo Finance with automatic
fallback to hardcoded rates. Used across all portfolio calculations.

**JSON API.** Read-only REST API authenticated via API keys. Endpoints for
portfolio NAV, asset allocation, FX exposure, companies, holdings, and
transactions.

**CSV export.** Download companies, holdings, transactions, chart of accounts,
or journal entries as CSV from any list page. Accounting exports accept an
optional company filter.

**Search.** Full-text search across companies, holdings, transactions, and
documents from the nav bar.

**Background workers.** Oban-powered scheduled jobs: daily price snapshots,
portfolio NAV snapshots, database backups, tax deadline reminders, and email
digests.

**Contacts and relationship management.** Track key people across the holding
structure: lawyers, accountants, bankers, regulators, advisors, and business
contacts. Link contacts to entities and documents with role tags and notes.

**Budget variance analysis.** Compare budgets to actuals with drill-down by
entity, period, and account.

**Cash flow forecasting.** Project future cash positions per entity based on
recurring revenues, expenses, loan repayments, and tax deadlines.

**KPI tracking.** Define and track custom key performance indicators per entity
with targets, trends, and threshold alerts.

**Concentration risk dashboard.** Alerts when a single asset, sector, currency,
or counterparty exceeds a configurable percentage of NAV.

**Debt maturity ladder.** Visual timeline of upcoming maturities across all
entities.

**Entity comparison.** Side-by-side financials and metrics across companies.

**Capital gains tax reports.** Generate FIFO, LIFO, or specific-lot reports per
jurisdiction with short-term vs long-term classification.

**Interactive org chart.** Visual entity structure diagram with click-through to
entity details.

**Unified calendar.** Merge tax deadlines, board meetings, compliance dates,
loan maturities, and filing deadlines into one calendar view.

**CSV/data import.** Import data from CSV files with column mapping and
validation.

**AI assistant.** LLM-powered chat available as a persistent slide-out drawer
from any page via a floating button. Configurable provider (Anthropic Claude,
OpenAI) with API key and model selection in Settings. Conversations are
persisted per user. The dashboard includes an inline AI Insights card that
generates a brief portfolio health summary on page load. The system prompt is
automatically populated with live portfolio data (NAV, holdings, companies,
allocation, liabilities, transactions, and tax deadlines) so the LLM has full
context to answer accurately.

## Quickstart

### Prerequisites

[Nix](https://nixos.org/) is the recommended way to get all dependencies.
`nix develop` gives you Elixir 1.18, Erlang/OTP 27, Node.js, and PostgreSQL.

Without Nix, you need:

- **Elixir** >= 1.15 and **Erlang/OTP** >= 26
- **PostgreSQL** >= 14
- **Node.js** (for asset pipeline)

### Setup

```bash
git clone https://github.com/unbalancedparentheses/holdco.git
cd holdco
make setup                   # deps, create DB, run migrations, build assets
make dev                     # http://localhost:4000
```

Or without Make:

```bash
nix develop --command mix setup
nix develop --command mix phx.server
```

Register at `/users/register`, then log in.

### Makefile targets

```
make setup          # mix setup (deps + DB + assets)
make dev            # mix phx.server
make test           # mix test
make lint           # format --check-formatted + compile --warnings-as-errors
make release        # prod assets + release build
make docker-build   # docker build -t holdco .
make docker-up      # docker compose up -d
make docker-down    # docker compose down
make seed           # mix run priv/repo/seeds.exs
make reset          # mix ecto.reset
make precommit      # format + compile + test
```

All local dev targets run through `nix develop --command`.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SECRET_KEY_BASE` | dev key | Production secret (min 64 bytes). Generate with `mix phx.gen.secret` |
| `DATABASE_URL` | `ecto://...` | PostgreSQL connection URL |
| `PHX_HOST` | `localhost` | Production hostname |
| `PORT` | `4000` | HTTP port |
| `PHX_SERVER` | unset | Set to `true` to start the server in releases |
| `POOL_SIZE` | `5` | Database connection pool size |

## Production Deployment

### Docker (recommended)

```bash
# Generate a secret
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Build and run
make docker-build
make docker-up
```

The `docker-compose.yml` includes a PostgreSQL service and persists data in a
named volume. The container runs as a non-root user and includes a healthcheck
on `/health`.

### Manual release

```bash
make release
SECRET_KEY_BASE=$(mix phx.gen.secret) \
DATABASE_URL=ecto://postgres:postgres@localhost/holdco \
PHX_HOST=holdco.example.com \
PHX_SERVER=true \
_build/prod/rel/holdco/bin/holdco start
```

### Nix build

```bash
nix build              # OTP release in ./result
nix build .#docker     # Docker image via dockerTools
```

The BackupWorker runs automated daily `pg_dump` backups if configured in Settings.

## API

Holdco exposes a read-only JSON API authenticated via API keys. Create a key
in Settings, then pass it as the `X-API-Key` header.

| Endpoint | Description |
|---|---|
| `GET /health` | Health check (no auth) |
| `GET /api/portfolio` | NAV breakdown |
| `GET /api/portfolio/allocation` | Asset allocation |
| `GET /api/portfolio/fx-exposure` | Currency exposure |
| `GET /api/companies` | List companies |
| `GET /api/companies/:id` | Company detail |
| `GET /api/holdings` | List holdings |
| `GET /api/transactions` | List transactions |

Example:

```bash
curl -H "X-API-Key: your-key-here" http://localhost:4000/api/portfolio
```

## CI

GitHub Actions runs on every push and PR to `main`:

1. **test** — compile with warnings-as-errors, format check, full test suite
2. **docker** — builds the Docker image on push to main (with layer caching)

## Testing

```bash
make test                    # run full suite
mix test --trace             # verbose output
```

## Architecture

| Component | Technology |
|---|---|
| Web framework | Phoenix 1.8 |
| UI | Phoenix LiveView 1.1 |
| Database | PostgreSQL via postgrex |
| Authentication | phx.gen.auth |
| Background jobs | Oban |
| Price data | Yahoo Finance via Req |
| Live updates | Phoenix PubSub |
| Charts | Chart.js via LiveView hooks |
| CSS | Tailwind CSS 4 + daisyUI v5 |

### Single-Tenant Design

Holdco is designed as a **single-tenant, self-hosted application**. There is no
multi-tenancy layer. One instance serves one holding company. All users share
the same data set, distinguished only by role (admin / editor / viewer). This is
intentional: holding company data is sensitive and should not be co-located with
other tenants. Deploy a separate instance per organization.

### Pages

| Route | Description |
|---|---|
| `/` | Dashboard: NAV, allocation chart, NAV history, corporate structure, recent activity |
| `/companies` | Company list with tree view, CSV export |
| `/companies/:id` | Company detail: holdings, bank accounts, transactions, documents, governance, compliance, financials, accounting |
| `/holdings` | All holdings with allocation chart, CSV export |
| `/holdings/:id` | Holding detail |
| `/transactions` | Transaction list with inflow/outflow summary, CSV export |
| `/transactions/:id` | Transaction detail |
| `/bank-accounts` | Bank accounts with balances, currency breakdown |
| `/bank-accounts/:id` | Bank account detail |
| `/documents` | Document library with file uploads |
| `/financials` | P&L with trend charts, budgets, intercompany transfers |
| `/contacts` | Contact management with role tags |
| `/calendar` | Unified calendar (deadlines, meetings, maturities) |
| `/org-chart` | Interactive org chart with click-through to entities |
| `/search` | Cross-table search (companies, holdings, transactions, documents) |
| `/governance` | Board composition, policies, resolutions |
| `/compliance` | Regulatory filings, licenses, insurance |
| `/board-meetings` | Agenda, minutes, resolutions, attendance |
| `/corporate-actions` | Dividends, share issues, mergers, spin-offs |
| `/registers` | Statutory shareholder/director/charge registers |
| `/share-classes` | Cap table with ownership percentages |
| `/related-party-transactions` | Intercompany transaction disclosure |
| `/accounts/chart` | Chart of accounts with company filter |
| `/accounts/journal` | Journal entries with balanced lines, company filter |
| `/accounts/reports` | Trial balance, balance sheet, income statement |
| `/accounts/integrations` | QuickBooks Online connection status per company |
| `/consolidated` | Consolidated financial statements with elimination entries |
| `/bank-reconciliation` | Match book entries to bank statements |
| `/period-locks` | Close periods to prevent edits |
| `/recurring-transactions` | Auto-generated repeating entries |
| `/budgets/variance` | Budget vs actual variance analysis |
| `/tax-provisions` | Tax liability per entity per jurisdiction |
| `/deferred-taxes` | Book vs tax basis differences |
| `/tax/capital-gains` | Cost basis tracking, realized/unrealized gains |
| `/tax-calendar` | Filing deadlines across entities and jurisdictions |
| `/transfer-pricing` | Arm's-length documentation, margin analysis |
| `/risk/concentration` | Exposure by type/counterparty/geography |
| `/counterparty-risk` | Weighted risk score per counterparty |
| `/covenants` | Financial ratio monitoring, breach detection |
| `/stress-test` | Apply shocks to portfolio, see impact on NAV |
| `/liquidity` | LCR calculation with HQLA tiering |
| `/debt-maturity` | Amortization schedules, upcoming maturities |
| `/cash-forecast` | Projected cash position from known flows |
| `/anomalies` | Statistical outlier and duplicate detection |
| `/benchmarks` | Portfolio return vs index, alpha computation |
| `/scenarios` | Financial projections with variable assumptions |
| `/defi-positions` | On-chain position tracking by chain/protocol |
| `/reports` | Report builder for board-ready output |
| `/kpis` | Configurable KPIs with trends |
| `/compare` | Side-by-side entity comparison |
| `/scheduled-reports` | Auto-generate and email reports on a schedule |
| `/contracts` | Cross-entity contract registry with expiry alerts |
| `/settings` | App settings, categories, backups, AI config |
| `/settings/notifications` | Notification preferences per user |
| `/audit-log` | Real-time audit stream via PubSub |
| `/approvals` | Approval workflows (N-of-M) |
| `/notifications` | Notification center |
| `/alerts` | Rule-based alert engine |
| `/import` | CSV/data import with column mapping |
| — | AI chat: persistent slide-out drawer accessible from any page |

### Project Layout

```
lib/holdco/              Bounded contexts and Ecto schemas
  accounts/              User, UserRole, ApiKey
  corporate/             Company tree, beneficial owners, key personnel
  governance/            Board meetings, resolutions
  assets/                Holdings, custodian accounts, cost basis lots
  banking/               Bank accounts, transactions
  finance/               Chart of accounts, journals, budgets, liabilities
  compliance/            Regulatory filings, insurance, sanctions
  documents/             Documents, versions, uploads
  treasury/              Cash pools
  pricing/               Price history, Yahoo Finance client (ETS cache)
  platform/              Settings, audit log, approvals
  integrations/          QuickBooks Online sync, bank feeds
  ai/                    LLM client, data context, conversations
  scenarios/             Scenario modeling with projection engine
  analytics/             KPIs, snapshots
  notifications/         In-app notification system
  depreciation/          Depreciation schedules (context, no UI)
  tax/                   Tax provisions, deferred taxes
  search.ex              Cross-table search
  portfolio.ex           NAV calculation, asset allocation, FX exposure, gains
  workers/               Oban workers (prices, snapshots, backups, tax reminders)
lib/holdco_web/
  controllers/api/       JSON API controllers
  controllers/           Health check, CSV export, auth, reports
  plugs/                 API key authentication plug
  live/                  52 LiveView modules
  components/            Layout, design system, Chart.js hook
  router.ex              All routes
Makefile                 Nix-wrapped dev commands
Dockerfile               Multi-stage production build
docker-compose.yml       Multi-service deployment with PostgreSQL
.github/workflows/ci.yml GitHub Actions CI (test + docker build)
flake.nix                Nix devShell + package build + Docker image
assets/css/app.css       Tailwind CSS 4 + daisyUI v5
priv/repo/migrations/    Migration files
priv/repo/seeds.exs      Example data
```

## Roadmap

Planned features organized by priority. Contributions welcome.

### Deepening existing pages

These pages exist but need more logic to be truly useful:

- **Cash Forecast** — Pull recurring transactions and known future cash flows,
  project daily/weekly cash position forward 90 days.
- **Debt Maturity** — Amortization schedule calculation, interest accrual,
  "what's due in 30/60/90 days" view.
- **Budget Variance** — Actual vs budget with variance % and drill-down by
  account/entity.
- **Bank Reconciliation** — Auto-match high-confidence entries, flag exceptions.
- **Alerts** — Verify Oban worker fires and alerts deliver via email/Slack.
- **Contracts** — Calendar view of expirations, auto-alerts at 30/60/90 days,
  counterparty concentration dashboard.
- **Scheduled Reports** — Email delivery, PDF generation, support for all
  report types.
- **Benchmarks** — Time-weighted returns, multiple benchmark support, period
  comparison.

### Automation and integrations

- **Bank feed via Plaid or GoCardless.** Auto-import transactions and reconcile.
- **Open banking (PSD2).** EU bank connections for automatic balance and
  transaction retrieval.
- **Mercury, Wise, and Revolut Business APIs.** Direct bank balance and
  transaction sync.
- **Xero integration.** Cover the other major accounting platform alongside
  QuickBooks.
- **Intercompany loan interest accrual.** Automatic interest calculations at
  arm's length rates with journal entry generation.
- **Backup to S3 or R2.** Push encrypted backups to object storage.
- **Import from Excel and Google Sheets.** Beyond CSV, handle `.xlsx` files.
- **Intercompany netting.** Net out payables and receivables across entities
  before settling.
- **Slack integration.** Push alerts to channels, query portfolio data.

### Advanced analytics

- **Valuation models.** DCF, comparables, and cap rate models for illiquid
  and private holdings.
- **Point-in-time snapshots.** View the corporate structure and portfolio as
  it was on any historical date.
- **Tax loss harvesting.** Identify positions to sell for tax losses based on
  cost basis lots and wash sale rules.
- **FX hedging tracker.** Log forward contracts, options, and swaps against FX
  exposures.

### Real assets and crypto

- **Real estate management.** Lease schedules, tenant tracking, rent rolls,
  and property-level P&L.
- **On-chain verification.** Pull balances directly from blockchain RPCs to
  verify custodial reports.

### Platform improvements

- **Write API.** Full read-write REST API for programmatic data entry and
  automation scripts.
- **Mobile-responsive dashboard.** Simplified mobile layout for checking NAV
  on the go.
- **Keyboard shortcuts.** Power-user navigation across all pages.
- **Dark mode.**

## License

MIT
