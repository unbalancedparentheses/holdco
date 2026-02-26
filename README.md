# Holdco

Open-source holding company management system built on Elixir, Phoenix, and LiveView.

<!-- TODO: add screenshot of dashboard -->

If you run a holding company, family office, or any multi-entity corporate
group, you need to track which companies you own, how they relate to each
other, what assets they hold, where those assets are custodied, what tax
deadlines are coming up, and what the financials look like across the whole
structure. Holdco does all of that in a single self-hosted application backed
by SQLite.

No SaaS, no vendor lock-in, no subscription. You own your data. Everything
runs locally or on your own server. The database is a single `.db` file you
can back up, copy, or move anywhere.

## Features

**Portfolio dashboard.** Net Asset Value calculated from liquid assets (bank
balances), marketable assets (stocks and crypto with live prices), illiquid
assets (real estate, private equity, funds), minus liabilities. Interactive
Chart.js charts for allocation and NAV history.

**Corporate structure.** Model your entire holding company tree with any depth
of nesting. Track ownership percentages, beneficial owners, key personnel,
service providers, and ownership changes per entity.

**Asset holdings and custody.** Equities, crypto, commodities, real estate,
private equity, funds, or any custom asset type. Link each holding to a
custodian account with bank name, account number, and authorized persons.
Cost basis lot tracking for tax reporting.

**Live prices.** Yahoo Finance integration for any ticker (stocks, ETFs,
BTC-USD, GC=F, EURUSD=X). ETS-cached with configurable TTL. Price history
snapshots via Oban background jobs.

**Bank accounts.** Operating, savings, FX, custody, and escrow accounts per
entity. IBAN, SWIFT/BIC, currency, balance, and authorized signers.

**Transactions.** Buy/sell, dividends, fees, distributions, capital calls.
Amount, currency, counterparty, date, linked to holdings and bank accounts.

**Liabilities.** Bank loans, bonds, credit lines, leases, intercompany loans.
Principal, interest rate, maturity date, currency, and status tracking.

**Financial tracking.** Revenue and expenses per entity per period with
multi-currency support. Chart of accounts, journal entries, inter-company
transfers, dividends, capital contributions, tax payments, and budgets.

**Governance.** Board meetings, cap table, shareholder resolutions, powers of
attorney, equity incentive plans and grants, M&A deal pipeline, joint ventures,
and investor access controls.

**Compliance.** Regulatory filings, licenses, insurance policies, compliance
checklists, transfer pricing documentation, withholding taxes, FATCA reports,
ESG scores, and sanctions screening.

**Tax calendar.** Filing deadlines per company and jurisdiction with status
tracking. Automated reminders via Oban background jobs.

**Documents.** Contracts, articles of incorporation, tax filings, agreements.
Document versioning and file uploads per company.

**Scenario modeling.** Financial projections with linear or compound growth
rates, recurrence, and probability weighting. Monthly projection charts.

**Audit log.** Every create, update, and delete is logged and streamed in
real-time via Phoenix PubSub.

**Role-based access control.** Three roles: admin (full access), editor
(create and update), viewer (read-only). Enforced at the LiveView level.
Authentication via email and password.

**Settings.** Custom categories with colors, webhooks, backup configurations,
API keys, and application-wide settings. Admin-only.

**Webhooks.** Configure webhook URLs in settings. Every data change fires a
JSON POST with HMAC-SHA256 signature to all active webhooks. Retry on failure.

**Automated backups.** Daily SQLite `.backup` to a configured path with
retention-based cleanup. Backup logs visible in settings.

**Sanctions screening.** Weekly automated screening of all companies and
beneficial owners against configured sanctions lists using fuzzy name matching.

**Email digests.** Weekly email summaries including portfolio NAV, upcoming
deadlines, recent audit activity, and transactions. Configurable per user.

**Gains tracking.** Unrealized and realized gain/loss calculations per holding
based on cost basis lots. Aggregate portfolio-level gains.

**Dynamic FX rates.** Live currency conversion via Yahoo Finance with automatic
fallback to hardcoded rates. Used across all portfolio calculations.

**JSON API.** Read-only REST API authenticated via API keys. Endpoints for
portfolio NAV, asset allocation, FX exposure, companies, holdings, and
transactions. HMAC-signed webhooks fire on every data change.

**CSV export.** Download companies, holdings, or transactions as CSV from any
list page.

**Search.** Full-text search across companies, holdings, transactions, and
documents from the nav bar.

**Background workers.** Oban-powered scheduled jobs: daily price snapshots,
portfolio NAV snapshots, database backups, tax deadline reminders, weekly
sanctions screening, and email digests.

## Quickstart

### Prerequisites

[Nix](https://nixos.org/) is the recommended way to get all dependencies.
`nix develop` gives you Elixir 1.18, Erlang/OTP 27, Node.js, and SQLite.

Without Nix, you need:

- **Elixir** >= 1.15 and **Erlang/OTP** >= 26
- **SQLite** >= 3.35 (ships with most systems)
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
| `DATABASE_PATH` | `holdco_dev.db` | Path to SQLite database file |
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

The `docker-compose.yml` persists the SQLite database in a named volume
(`holdco_data:/data`). The container runs as a non-root user and includes a
healthcheck on `/health`.

### Manual release

```bash
make release
SECRET_KEY_BASE=$(mix phx.gen.secret) \
DATABASE_PATH=/var/lib/holdco/holdco.db \
PHX_HOST=holdco.example.com \
PHX_SERVER=true \
_build/prod/rel/holdco/bin/holdco start
```

### Nix build

```bash
nix build              # OTP release in ./result
nix build .#docker     # Docker image via dockerTools
```

The SQLite database is a single file. Back it up with `cp` or `sqlite3 .backup`.
The BackupWorker also runs automated daily backups if configured in Settings.

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
| Database | SQLite via ecto_sqlite3 |
| Authentication | phx.gen.auth |
| Background jobs | Oban (Lite engine for SQLite) |
| Price data | Yahoo Finance via Req |
| Live updates | Phoenix PubSub |
| Charts | Chart.js via LiveView hooks |
| CSS | FT-inspired design system |

### Pages

| Route | Description |
|---|---|
| `/` | Dashboard: NAV, allocation chart, NAV history, corporate structure, recent activity |
| `/companies` | Company list with tree view, CSV export |
| `/companies/:id` | Company detail: holdings, accounts, transactions, documents, governance, compliance |
| `/holdings` | All holdings with allocation chart, CSV export |
| `/transactions` | Transaction list with inflow/outflow summary, CSV export |
| `/bank-accounts` | Bank accounts with balances, currency breakdown, cash pools |
| `/documents` | Document library with file uploads |
| `/tax-calendar` | Tax deadlines and annual filings |
| `/financials` | P&L with trend charts, budgets, intercompany transfers |
| `/governance` | Board meetings, cap table, resolutions, equity plans, deals |
| `/compliance` | Regulatory filings, licenses, insurance, sanctions, ESG |
| `/scenarios` | Scenario list |
| `/scenarios/:id` | Scenario detail with projection charts |
| `/search` | Cross-table search (companies, holdings, transactions, documents) |
| `/audit-log` | Real-time audit stream via PubSub |
| `/settings` | App settings, categories, webhooks, backups (admin only) |

### Project Layout

```
lib/holdco/              14 bounded contexts, 74 Ecto schemas
  accounts/              User, UserRole, ApiKey
  corporate/             Company tree, beneficial owners, key personnel
  governance/            Board meetings, cap table, resolutions, equity plans, deals
  assets/                Holdings, custodian accounts, cost basis lots, crypto, real estate
  banking/               Bank accounts, transactions
  finance/               Financials, chart of accounts, journals, dividends, budgets, liabilities
  compliance/            Tax deadlines, regulatory filings, insurance, sanctions, ESG
  documents/             Documents, versions, uploads
  treasury/              Cash pools
  pricing/               Price history, Yahoo Finance client (ETS cache)
  platform/              Settings, categories, audit log, webhooks (with delivery), backups
  integrations/          Accounting sync, bank feeds, e-signatures, email digests
  scenarios/             Scenario modeling with projection engine
  search.ex              Cross-table search
  portfolio.ex           NAV calculation, asset allocation, FX exposure, gains
  workers/               Oban workers (prices, snapshots, backups, sanctions, email digests, tax reminders)
lib/holdco_web/
  controllers/api/       JSON API controllers (portfolio, companies, holdings, transactions)
  controllers/           Health check, CSV export, auth controllers
  plugs/                 API key authentication plug
  live/                  16 LiveView modules (including search)
  components/            Layout, design system, Chart.js hook
  router.ex              All routes
Makefile                 Nix-wrapped dev commands
Dockerfile               Multi-stage production build
docker-compose.yml       Single-service deployment with SQLite volume
.github/workflows/ci.yml GitHub Actions CI (test + docker build)
flake.nix                Nix devShell + package build + Docker image
assets/css/ft.css        FT-inspired design system
priv/repo/migrations/    Ecto migrations (74 tables)
priv/repo/seeds.exs      Example data
```

## Roadmap

Planned features organized by priority. Contributions welcome.

### Phase 1 — Core reporting and daily workflow

These extend existing data into immediately useful outputs.

- **Capital gains tax report.** Generate FIFO, LIFO, or specific-lot reports per
  jurisdiction with short-term vs long-term classification. Built on the existing
  cost basis lot data.
- **Consolidated financial statements.** Automatic elimination of intercompany
  balances and transactions for group-level reporting.
- **Cash flow forecasting.** Project future cash positions per entity based on
  recurring revenues, expenses, loan repayments, and tax deadlines already in
  the system.
- **PDF report generation.** One-click board pack with portfolio summary,
  financials, compliance status, and upcoming deadlines.
- **Unified calendar view.** Merge tax deadlines, board meetings, compliance
  dates, loan maturities, and filing deadlines into one calendar.
- **Concentration risk dashboard.** Alerts when a single asset, sector,
  currency, or counterparty exceeds a configurable percentage of NAV.
- **Field-level audit diffs.** Show what changed (old value to new value), not
  just that something changed.
- **Debt maturity ladder.** Visual timeline of upcoming maturities across all
  entities.
- **Internal messaging and notes.** Threaded comments on any entity, surfacing
  the existing comments table in the UI.

### Phase 2 — Automation and integrations

Reduce manual data entry and connect to external systems.

- **Bank feed via Plaid or GoCardless.** Auto-import transactions and reconcile
  against manual entries using the existing bank_feed framework.
- **Mercury, Wise, and Revolut Business APIs.** Direct bank balance and
  transaction sync for fintech-native holding companies.
- **Xero integration.** Cover the other major accounting platform alongside
  QuickBooks.
- **Intercompany loan interest accrual.** Automatic interest calculations at
  arm's length rates with journal entry generation.
- **Multi-sig approval workflows.** Require N-of-M approvals for transactions
  above a threshold, dividend declarations, or new entity creation. Extends the
  existing approval_requests infrastructure.
- **Task management.** Assign follow-ups from board meetings, compliance
  deadlines, or audit findings to specific users with due dates.
- **Scheduled reports.** Extend email digests with custom report schedules such
  as monthly board packs and quarterly compliance summaries.
- **Backup to S3 or R2.** Extend the backup worker to push encrypted backups to
  object storage instead of only local paths.
- **Bulk operations.** Batch-edit holdings, batch-assign categories, and
  bulk-approve pending items.

### Phase 3 — Advanced analytics and risk

Turn the platform into a decision-making tool.

- **Stress testing.** Extend scenario modeling with market shocks (e.g. BTC
  drops 40%, EUR/USD moves 10%) applied to the actual portfolio.
- **Liquidity coverage ratio.** Compare liquid assets to short-term liabilities
  and upcoming obligations such as loan maturities and tax payments.
- **Counterparty risk scoring.** Rate custodians and banks by exposure,
  jurisdiction, and credit rating.
- **Loan covenant monitoring.** Track financial covenants (debt/equity ratio,
  interest coverage) with automated breach alerts based on actual financials.
- **Anomaly detection.** Flag unusual transactions, balance changes, or patterns
  such as unexpected large outflows or duplicate payments.
- **Benchmark comparison.** Compare portfolio allocation and returns against
  standard indices.
- **Valuation models.** DCF, comparables, and cap rate models for illiquid and
  private holdings instead of just manual entry.
- **Point-in-time snapshots.** View the entire corporate structure and portfolio
  as it was on any historical date.

### Phase 4 — Fund, LP, and tax structures

For holding companies with fund entities or complex tax planning needs.

- **K-1 and distribution waterfall.** Model LP/GP economics for fund entities
  with hurdle rates, catch-up, and carry calculations.
- **Capital call and distribution management.** Track called vs uncalled capital,
  RVPI, TVPI, and DPI multiples for PE and VC fund commitments.
- **Fund NAV and investor statements.** Generate LP statements with performance
  attribution for fund entities.
- **Fee tracking.** Management fees, performance fees, and carried interest
  across fund investments.
- **Dividend policy engine.** Automate dividend calculations based on
  configurable rules such as distributing a percentage of net income above a
  reserve threshold.
- **Multi-jurisdiction tax optimizer.** Given the entity tree and transfer
  pricing docs, suggest dividend routes or IP licensing structures that minimize
  withholding taxes.
- **Repatriation planning.** Track trapped cash per jurisdiction and model
  optimal repatriation routes considering withholding taxes and treaty networks.

### Phase 5 — Corporate lifecycle and governance

Full entity management from incorporation to dissolution.

- **Entity lifecycle management.** Incorporation, dormancy, winding-down, and
  dissolution workflows with jurisdiction-specific checklists.
- **Corporate secretarial registers.** Statutory books (share register, director
  register, charge register) required by most jurisdictions.
- **Corporate actions.** Stock splits, mergers, spin-offs, and their cascading
  impact on holdings and cost basis.
- **Succession and estate planning.** Model generational transfers, trust
  structures, and what happens to the org chart when key persons change.
- **Document e-signature workflow.** Build the full signing flow with reminders
  and status tracking on top of the existing signature_requests schema.
- **DocuSign and PandaDoc.** Complete the e-signature integration.
- **Full KYC/AML workflow.** Beyond sanctions screening, track document
  collection, verification status, and periodic review cycles per entity and
  beneficial owner.
- **Reporting templates.** Pre-built templates for CRS, FATCA, BO registers, and
  other jurisdiction-specific filings.

### Phase 6 — Real assets, crypto, and DeFi

Deeper support for non-traditional asset classes.

- **Real estate management.** Lease schedules, tenant tracking, rent rolls,
  maintenance costs, and property-level P&L for real estate holdings.
- **DeFi position tracking.** Staking, lending, liquidity pool positions, and
  yield farming across protocols.
- **On-chain verification.** Pull balances directly from blockchain RPCs to
  verify custodial reports.
- **Airdrop and fork tracking.** Record cost basis for received tokens.
- **Sweep accounts and rebalancing rules.** Define target balances per account
  and generate transfer suggestions when thresholds are breached.
- **FX hedging tracker.** Log forward contracts, options, and swaps against FX
  exposures the system already calculates.

### Phase 7 — Multi-tenant, access control, and intelligence

Scale from single-user to multi-stakeholder platform.

- **Investor portal.** Read-only view for LPs and investors showing their
  specific holdings, distributions, and reports. Built on the existing
  investor_accesses table.
- **Advisor view.** Let external accountants or lawyers see only the entities and
  documents relevant to them.
- **Virtual data room.** Secure, permissioned document sharing for M&A due
  diligence. Extends the existing documents module.
- **SSO and SAML.** Enterprise authentication alongside the existing
  email/password flow.
- **Natural language query.** Ask questions like "What is our total exposure to
  EUR?" or "Show me all entities with tax deadlines this quarter" using an LLM
  against the structured data.
- **Regulatory change monitoring.** Subscribe to jurisdictions and get alerts
  when relevant regulations change.
- **Multi-user real-time collaboration.** Presence indicators ("Alice is viewing
  this company") via LiveView presence.

### Phase 8 — Platform extensibility

Open the system up for custom workflows and external tools.

- **GraphQL API.** Alongside the existing REST API for more flexible queries.
- **Telegram and Slack bot.** Push notifications and quick queries via chat.
- **BI tool export.** Direct connectors or scheduled exports for Metabase,
  Grafana, or Excel Power Query.
- **Plugin and extension system.** Let users add custom modules without forking.
- **White-labeling.** Configurable branding (logo, colors, app name) per tenant
  group.
- **Mobile-responsive dashboard.** Simplified mobile layout for checking NAV on
  the go.
- **Keyboard shortcuts.** Power-user navigation across all pages.
- **Multi-language and i18n.** Especially relevant for multi-jurisdiction holding
  companies.
- **Dark mode.**

## License

MIT
