# Holdco

Open-source holding company management system built with Elixir, Phoenix LiveView, and PostgreSQL.

If you run a holding company or any multi-entity corporate group, you need to
track which companies you own, how they relate to each other, what assets they
hold, where those assets are custodied, what tax deadlines are coming up, and
what the financials look like across the whole structure. Holdco does all of
that in a single self-hosted application.

No SaaS, no vendor lock-in, no subscription. You own your data.

## What It Actually Does

### Portfolio Intelligence

The dashboard is not a dumb list of numbers. It computes:

- **Net Asset Value** segmented into liquid (bank balances), marketable (stocks,
  crypto, commodities with live prices from Yahoo Finance), and illiquid (real
  estate, private equity, funds), minus liabilities.
- **Return metrics** — total return %, unrealized and realized gains, computed
  from cost basis lots with FIFO/LIFO/specific lot support.
- **Period-over-period comparison** — NAV change vs 1 week, 1 month, 3 months,
  YTD, and 1 year ago using historical snapshots.
- **90-day cash flow forecast** — projects future cash from recurring
  transactions (expanded by frequency) and upcoming debt maturities, with a
  running balance chart.
- **Financial ratios** — debt-to-equity, current ratio, liquidity ratio,
  weighted average interest rate on debt.
- **Entity-level performance** — per-company breakdown of cash, holdings,
  liabilities, NAV, and return percentage. Answers "which subsidiary is
  performing best?"

All values convert to a single display currency via live FX rates.

### Corporate Structure

Model your entire holding company tree with any depth of nesting. Track
ownership percentages, beneficial owners, key personnel, service providers,
and ownership changes per entity. The company detail page consolidates
holdings, bank accounts, transactions, documents, governance records,
compliance items, financials, and accounting into tabbed views.

### Double-Entry Accounting

Full chart of accounts with hierarchical structure, journal entries with
balanced debit/credit lines, trial balance, balance sheet, and income
statement. Each company owns its own accounts; global pages show consolidated
views with company filter dropdowns. Period locks prevent edits to closed
periods. Recurring transactions auto-generate journal entries via Oban
background jobs.

### Bank Reconciliation

A real scoring engine matches book entries against bank feed transactions:
50 points for exact amount match (partial credit within 5%), 30 points for
date proximity, 20 points for Jaro-Winkler description similarity. Auto-match
at 60+ points. Manual override for exceptions. Import bank statements via CSV
upload with AI-powered parsing, or connect directly via bank APIs.

### Risk and Analytics

- **Concentration risk** — HHI index, max position %, per-holding % of NAV,
  alerts when any position exceeds 25%.
- **Stress testing** — apply ticker-level, asset-type, or FX shocks to the
  portfolio and see per-holding impact on NAV.
- **Anomaly detection** — 3-sigma outlier detection, duplicate detection,
  10x-median unusual amount flagging, and 50%+ period-over-period revenue/expense
  change detection.
- **Debt maturity ladder** — bucket liabilities by time horizon (0-1yr, 1-3yr,
  3-5yr, 5+yr), weighted average interest rate, upcoming maturity alerts.
- **Cash forecast** — 12-month projection from detected recurring patterns,
  liability maturities, and tax deadline outflows with Chart.js visualization.
- **Budget variance** — actual vs budget by category with $ and % variance,
  grouped bar charts.

### Tax

- **Capital gains** — FIFO, LIFO, or specific lot identification. Short-term vs
  long-term classification (365-day rule). Realized and unrealized gains per lot.
  Tax estimate at 37%/20%.
- **Tax provisions** per entity per jurisdiction.
- **Deferred taxes** — book vs tax basis differences with inline calculator.
- **Tax calendar** — filing deadlines across entities and jurisdictions with
  status tracking.
- **Transfer pricing** — arm's-length variance computation, color-coded by
  deviation severity.

### Integrations

- **QuickBooks Online** — OAuth2 connection with automatic token refresh. Sync
  chart of accounts and journal entries per company.
- **Xero** — OAuth2 connection for accounting sync.
- **Bank Statement Import** — upload CSV bank statements, AI-powered parsing
  (via Anthropic or OpenAI), automatic dedup via content hashing.
- **Yahoo Finance** — live prices for any ticker (stocks, ETFs, crypto,
  commodities, FX pairs). ETS-cached with configurable TTL.

### AI Assistant

LLM-powered chat available as a persistent slide-out drawer from any page.
Supports Anthropic Claude and OpenAI. Conversations are persisted per user.
The system prompt is automatically populated with live portfolio data (NAV,
holdings, companies, allocation, liabilities, transactions, tax deadlines)
so the LLM has full context.

### Background Workers

Oban-powered scheduled jobs that run automatically:

| Worker | What it does |
|---|---|
| `SnapshotPricesWorker` | Fetches live prices for all holding tickers |
| `PortfolioSnapshotWorker` | Records daily NAV snapshots for historical charts |
| `BackupWorker` | `pg_dump` to disk with retention cleanup, optional S3/R2 upload |
| `RecurringTransactionWorker` | Posts journal entries for due recurring transactions |
| `InterestAccrualWorker` | Generates interest accrual entries for intercompany loans |
| `AlertEngineWorker` | Evaluates alert rules against live metrics |
| `SanctionsCheckWorker` | Screens company names against sanctions lists (Jaro similarity) |
| `TaxReminderWorker` | Sends notifications for tax deadlines due within 14 days |
| `ScheduledReportWorker` | Generates and emails HTML reports (portfolio, trial balance, compliance) |
| `EmailDigestWorker` | Weekly email summaries of portfolio, deadlines, and activity |

### Everything Else

- **Audit log** — every create, update, delete is logged and streamed in
  real-time via PubSub.
- **Approval workflows** — N-of-M approvals for sensitive actions.
- **Role-based access** — admin, editor, viewer. Enforced at the LiveView
  level. Email/password auth with optional TOTP 2FA.
- **Consolidated statements** — automatic elimination of intercompany balances.
- **CSV import/export** — companies, holdings, transactions, chart of accounts,
  journal entries.
- **JSON API** — read-only REST endpoints for NAV, allocation, FX exposure,
  companies, holdings, transactions.
- **Search** — cross-table search across companies, holdings, transactions,
  documents.
- **Contracts** — cross-entity registry with counterparty tracking.
- **Contacts** — people and organizations across the holding structure.
- **Documents** — file uploads per company with versioning.

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
export SECRET_KEY_BASE=$(mix phx.gen.secret)
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

## API

Read-only JSON API authenticated via API keys. Create a key in Settings, then
pass it as the `X-API-Key` header.

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

```bash
curl -H "X-API-Key: your-key-here" http://localhost:4000/api/portfolio
```

## Testing

```bash
make test             # ~4,000 tests
mix test --trace      # verbose output
```

## Architecture

| Component | Technology |
|---|---|
| Web framework | Phoenix 1.8 |
| UI | Phoenix LiveView 1.1 |
| Database | PostgreSQL via Ecto |
| Authentication | phx.gen.auth + TOTP |
| Background jobs | Oban |
| Price data | Yahoo Finance via Req |
| Live updates | Phoenix PubSub |
| Charts | Chart.js via LiveView hooks |
| CSS | Tailwind CSS 4 + daisyUI v5 |

### Single-Tenant Design

Holdco is a **single-tenant, self-hosted application**. There is no
multi-tenancy layer. One instance serves one holding company. All users share
the same data set, distinguished only by role. Holding company data is
sensitive and should not be co-located with other tenants. Deploy a separate
instance per organization.

### Pages

| Route | Description |
|---|---|
| `/` | Dashboard: NAV, returns, period comparison, ratios, cash forecast, entity performance |
| `/companies` | Company list with tree view |
| `/companies/:id` | Company detail: holdings, bank accounts, transactions, documents, governance, compliance, financials, accounting |
| `/holdings` | All holdings with allocation chart |
| `/holdings/:id` | Holding detail with cost basis lots |
| `/transactions` | Transaction list with inflow/outflow summary |
| `/transactions/:id` | Transaction detail |
| `/bank-accounts` | Bank accounts with balances and currency breakdown |
| `/bank-accounts/:id` | Bank account detail |
| `/documents` | Document library with file uploads |
| `/financials` | P&L with trend charts, budgets, intercompany transfers |
| `/contacts` | Contact management |
| `/contracts` | Cross-entity contract registry |
| `/calendar` | Unified calendar (deadlines, meetings, maturities) |
| `/tax-calendar` | Tax filing deadlines by entity and jurisdiction |
| `/org-chart` | Interactive org chart |
| `/search` | Cross-table search |
| `/accounts/chart` | Chart of accounts |
| `/accounts/journal` | Journal entries |
| `/accounts/reports` | Trial balance, balance sheet, income statement |
| `/accounts/integrations` | QuickBooks Online / Xero connection status |
| `/consolidated` | Consolidated financial statements |
| `/bank-reconciliation` | Match book entries to bank statements |
| `/period-locks` | Close periods to prevent edits |
| `/recurring-transactions` | Auto-generated repeating entries |
| `/budgets/variance` | Budget vs actual variance analysis |
| `/tax-provisions` | Tax liability per entity per jurisdiction |
| `/deferred-taxes` | Book vs tax basis differences |
| `/tax/capital-gains` | FIFO/LIFO cost basis, realized/unrealized gains |
| `/transfer-pricing` | Arm's-length documentation |
| `/risk/concentration` | Exposure by type/counterparty/geography |
| `/stress-test` | Apply shocks to portfolio, see impact on NAV |
| `/anomalies` | Statistical outlier and duplicate detection |
| `/debt-maturity` | Maturity ladder and upcoming maturities |
| `/cash-forecast` | 12-month projected cash position |
| `/compare` | Side-by-side entity comparison |
| `/scheduled-reports` | Auto-generate and email reports on a schedule |
| `/alerts` | Rule-based alert engine |
| `/approvals` | Approval workflows |
| `/audit-log` | Real-time audit stream |
| `/notifications` | Notification center |
| `/settings` | App settings, categories, backups, AI config |
| `/import` | CSV import with column mapping |
| `/reports` | Report builder |
| — | AI chat: persistent drawer accessible from any page |

### Project Layout

```
lib/holdco/              Bounded contexts and Ecto schemas
  accounts/              User, UserRole, ApiKey, TOTP
  corporate/             Company tree, beneficial owners, key personnel, governance
  assets/                Holdings, custodian accounts, cost basis lots, snapshots
  banking/               Bank accounts, transactions
  finance/               Chart of accounts, journals, budgets, liabilities, leases
  compliance/            Regulatory filings, insurance, sanctions, tax deadlines
  documents/             Documents, versions, uploads
  tax/                   Tax provisions, deferred taxes, capital gains
  pricing/               Price history, Yahoo Finance client (ETS cache)
  platform/              Settings, audit log, approvals, alerts
  integrations/          QuickBooks sync, Xero sync, bank feeds, reconciliation
  ai/                    LLM client, data context, conversations
  notifications/         In-app notification system
  analytics/             Anomaly detection, stress testing
  portfolio.ex           NAV, returns, ratios, cash forecast, entity performance
  money.ex               Decimal arithmetic helpers
  search.ex              Cross-table search
  workers/               10 Oban workers
lib/holdco_web/
  controllers/api/       JSON API controllers
  controllers/           Health, CSV export, auth, reports, QBO/Xero OAuth
  plugs/                 API key authentication
  live/                  ~45 LiveView modules
  components/            Layout, design system, Chart.js hook
  router.ex              All routes
```

## Roadmap

Development follows user workflows — build the daily/monthly core loop first,
then expand outward.

### Phase 1: "I can see what I own" (done)

Portfolio dashboard with NAV, returns, allocation, ratios, entity performance,
corporate structure tree, and live FX. CSV import/export for all major tables.

### Phase 2: "I can track my money" (done)

Bank statement import (CSV upload with AI parsing), bank reconciliation with
scoring engine and inline one-click matching, reconciliation status on bank
account pages. The import → reconcile pipeline works end-to-end.

### Phase 3: "I can close my books" (done)

Period close checklist that ties reconciliation → journal entries → period lock
into one guided flow per entity. Consolidated financial statements with
intercompany eliminations and NCI, exportable to CSV. Recurring transaction
auto-posting via background worker.

### Phase 4: "I can stay compliant" (partially done)

Tax provisions, deferred taxes, capital gains with lot tracking, tax calendar,
transfer pricing. Audit log and approval workflows. Still needed:

- **Audit package improvements.** Include consolidated statements in the
  zip export.
- **Tax loss harvesting.** Identify positions to sell based on cost basis
  lots and wash sale rules.

### Phase 5: "I can manage risk" (partially done)

Concentration risk, stress testing, anomaly detection, debt maturity ladder,
cash forecast. Still needed:

- **Scheduled anomaly detection.** Run nightly via Oban instead of manual.
- **Monte Carlo simulation.** Probabilistic stress testing beyond linear shocks.

### Phase 6: "I can report to stakeholders" (partially done)

Scheduled reports, print-friendly views, JSON API. Still needed:

- **Streaming AI responses.** Token-by-token output.
- **Write API.** Full read-write REST API.
- **Mobile-responsive dashboard.**

### Integrations Roadmap

- **Open banking (PSD2).** EU bank connections for automatic balance and
  transaction retrieval.
- **Mercury, Wise, Revolut Business APIs.** Direct bank balance sync.
- **Intercompany netting.** Net payables/receivables across entities before
  settling.
- **Slack integration.** Push alerts to channels.

## License

MIT
