# Holdco

Open-source holding company management system built on Elixir, Phoenix, and LiveView.

<!-- TODO: add screenshot of dashboard -->

If you run a holding company, family office, or any multi-entity corporate
group, you need to track which companies you own, how they relate to each
other, what assets they hold, where those assets are custodied, what tax
deadlines are coming up, and what the financials look like across the whole
structure. Holdco does all of that in a single self-hosted application backed
by PostgreSQL.

No SaaS, no vendor lock-in, no subscription. You own your data. Everything
runs locally or on your own server.

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
multi-currency support. Inter-company transfers, dividends, capital
contributions, tax payments, and budgets.

**Double-entry accounting.** Full chart of accounts, journal entries with
balanced debit/credit lines, trial balance, balance sheet, and income
statement. All accounting data is entity-scoped: each company owns its own
accounts and journal entries, global pages show consolidated views with company
filter dropdowns. QuickBooks Online integration syncs accounts and journal
entries into a specific company.

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
Authentication via email and password with optional TOTP two-factor
authentication.

**Settings.** Custom categories with colors, webhooks, backup configurations,
API keys, and application-wide settings. Admin-only.

**Webhooks.** Configure webhook URLs in settings. Every data change fires a
JSON POST with HMAC-SHA256 signature to all active webhooks. Retry on failure.

**QuickBooks Online integration.** OAuth2 connection with automatic token
refresh. Sync chart of accounts and journal entries from QBO into a specific
company entity. Each subsidiary connects independently from its company detail
page; the global integrations page shows a summary dashboard of all connections.

**Automated backups.** Daily PostgreSQL `pg_dump` backups to a configured path
with retention-based cleanup. Backup logs visible in settings.

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

**CSV export.** Download companies, holdings, transactions, chart of accounts,
or journal entries as CSV from any list page. Accounting exports accept an
optional company filter.

**Search.** Full-text search across companies, holdings, transactions, and
documents from the nav bar.

**Background workers.** Oban-powered scheduled jobs: daily price snapshots,
portfolio NAV snapshots, database backups, tax deadline reminders, weekly
sanctions screening, and email digests.

**Contacts and relationship management.** Track key people across the holding
structure: lawyers, accountants, bankers, regulators, investors, advisors, and
business contacts. Link contacts to entities, deals, and documents with role
tags, interaction history, and notes.

**Project pipeline.** Track active and planned projects across the group with
status, responsible contacts, milestones, budgets, and linked entities. Covers
M&A due diligence, entity restructurings, system migrations, fundraises, or
any multi-step initiative.

**Depreciation and amortization schedules.** Straight-line, declining balance,
and units-of-production methods for fixed assets and intangibles with automatic
journal entry generation.

**Lease accounting (IFRS 16 / ASC 842).** Right-of-use asset calculations,
lease liability amortization, and the journal entries required for compliance
with modern lease accounting standards.

**Budget variance analysis.** Compare budgets to actuals with drill-down by
entity, period, and account.

**Cash flow forecasting.** Project future cash positions per entity based on
recurring revenues, expenses, loan repayments, and tax deadlines.

**Segment reporting.** Slice financials by business segment, geography, or any
custom dimension.

**KPI tracking.** Define and track custom key performance indicators per entity
with targets, trends, and threshold alerts.

**Management reporting packages.** Customizable monthly and quarterly report
templates assembled from existing data.

**AR/AP aging reports.** Accounts receivable and accounts payable aging by
entity showing who owes you, who you owe, and how overdue each balance is.

**Concentration risk dashboard.** Alerts when a single asset, sector, currency,
or counterparty exceeds a configurable percentage of NAV.

**Debt maturity ladder.** Visual timeline of upcoming maturities across all
entities.

**Entity comparison.** Side-by-side financials and metrics across companies.

**Waterfall charts.** Visualize P&L bridges and NAV change attribution.

**Currency revaluation.** Period-end FX revaluation of foreign-currency balances
with translation adjustments posted to the P&L.

**Capital gains tax reports.** Generate FIFO, LIFO, or specific-lot reports per
jurisdiction with short-term vs long-term classification.

**Interactive org chart.** Visual entity structure diagram with click-through to
entity details.

**Unified calendar.** Merge tax deadlines, board meetings, compliance dates,
loan maturities, and filing deadlines into one calendar view.

**Field-level audit diffs.** Show what changed (old value to new value), not
just that something changed.

**Approval workflows.** Require N-of-M approvals for transactions above a
threshold, dividend declarations, or new entity creation.

**Consolidated financial statements.** Automatic elimination of intercompany
balances and transactions for group-level reporting.

**Notifications.** In-app notification center for system events, deadline
reminders, and approval requests.

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
npx playwright test          # 260 end-to-end tests (Playwright)
```

The project includes 260 Playwright end-to-end tests covering all LiveView pages
and user workflows alongside the ExUnit unit test suite.

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
| `/companies/:id` | Company detail: holdings, bank accounts, transactions, documents, governance, compliance, financials, accounting, comments |
| `/holdings` | All holdings with allocation chart, CSV export |
| `/transactions` | Transaction list with inflow/outflow summary, CSV export |
| `/bank-accounts` | Bank accounts with balances, currency breakdown, cash pools |
| `/documents` | Document library with file uploads |
| `/tax-calendar` | Tax deadlines and annual filings |
| `/financials` | P&L with trend charts, budgets, intercompany transfers |
| `/accounts/chart` | Chart of accounts with company filter |
| `/accounts/journal` | Journal entries with balanced lines, company filter |
| `/accounts/reports` | Trial balance, balance sheet, income statement per company or consolidated |
| `/accounts/integrations` | QuickBooks Online summary dashboard: connection status per company |
| `/governance` | Board meetings, cap table, resolutions, equity plans, deals |
| `/compliance` | Regulatory filings, licenses, insurance, sanctions, ESG |
| `/scenarios` | Scenario list |
| `/scenarios/:id` | Scenario detail with projection charts |
| `/search` | Cross-table search (companies, holdings, transactions, documents) |
| `/audit-log` | Real-time audit stream via PubSub |
| `/org-chart` | Interactive org chart with click-through to entities |
| `/contacts` | Contact management with role tags and interaction history |
| `/projects` | Project pipeline with milestones and budgets |
| `/notifications` | Notification center |
| `/calendar` | Unified calendar (deadlines, meetings, maturities) |
| `/approvals` | Approval workflows (N-of-M) |
| `/import` | CSV/data import with column mapping |
| `/reports` | Printable report generation |
| `/consolidated` | Consolidated financial statements |
| `/depreciation` | Depreciation and amortization schedules |
| `/leases` | Lease accounting (IFRS 16 / ASC 842) |
| `/segments` | Segment reporting |
| `/budgets/variance` | Budget vs actual variance analysis |
| `/cash-forecast` | Cash flow forecasting |
| `/kpis` | KPI tracking with targets and thresholds |
| `/management-reports` | Management reporting packages |
| `/tax/capital-gains` | Capital gains tax reports |
| `/risk/concentration` | Concentration risk dashboard |
| `/debt-maturity` | Debt maturity ladder |
| `/waterfall` | Waterfall charts (P&L bridges, NAV attribution) |
| `/compare` | Entity comparison (side-by-side financials) |
| `/aging` | AR/AP aging reports |
| `/revaluation` | Currency revaluation |
| `/audit-diffs` | Field-level audit diffs (old → new values) |
| — | AI chat: persistent slide-out drawer accessible from any page via floating button |
| `/settings` | App settings, categories, webhooks, backups, AI config (admin only) |

### Project Layout

```
lib/holdco/              19 bounded contexts, 89 Ecto schemas
  accounts/              User, UserRole, ApiKey
  corporate/             Company tree, beneficial owners, key personnel
  governance/            Board meetings, cap table, resolutions, equity plans, deals
  assets/                Holdings, custodian accounts, cost basis lots, crypto, real estate
  banking/               Bank accounts, transactions
  finance/               Financials, chart of accounts (entity-scoped), journals, dividends, budgets, liabilities, leases, segments, fixed assets
  compliance/            Tax deadlines, regulatory filings, insurance, sanctions, ESG
  documents/             Documents, versions, uploads
  treasury/              Cash pools
  pricing/               Price history, Yahoo Finance client (ETS cache)
  platform/              Settings, categories, audit log, webhooks (with delivery), backups, approvals
  integrations/          QuickBooks Online sync, bank feeds, e-signatures, email digests
  ai/                    LLM client, data context, conversations, messages
  scenarios/             Scenario modeling with projection engine
  analytics/             KPIs, snapshots, report templates
  collaboration/         Contacts, projects, comments
  depreciation/          Depreciation and amortization schedules
  notifications/         In-app notification system
  search.ex              Cross-table search
  portfolio.ex           NAV calculation, asset allocation, FX exposure, gains
  workers/               Oban workers (prices, snapshots, backups, sanctions, email digests, tax reminders)
lib/holdco_web/
  controllers/api/       JSON API controllers (portfolio, companies, holdings, transactions)
  controllers/           Health check, CSV export, auth, reports, XBRL controllers
  plugs/                 API key authentication plug
  live/                  48 LiveView modules covering all routes below
  components/            Layout, design system, Chart.js hook
  router.ex              All routes
Makefile                 Nix-wrapped dev commands
Dockerfile               Multi-stage production build
docker-compose.yml       Multi-service deployment with PostgreSQL
.github/workflows/ci.yml GitHub Actions CI (test + docker build)
flake.nix                Nix devShell + package build + Docker image
assets/css/app.css       Tailwind CSS 4 + daisyUI v5
priv/repo/migrations/    10 migration files
priv/repo/seeds.exs      Example data
```

## Roadmap

Planned features organized by priority. Contributions welcome.

### Phase 1 — Core reporting and daily workflow (complete)

All 24 Phase 1 features have been implemented with working LiveView pages and
260 passing end-to-end tests. Delivered:

- Capital gains tax reports (FIFO, LIFO, specific-lot)
- Consolidated financial statements with intercompany elimination
- Cash flow forecasting per entity
- PDF/printable report generation
- Unified calendar view (deadlines, meetings, maturities)
- Concentration risk dashboard with configurable thresholds
- Field-level audit diffs (old → new values)
- Debt maturity ladder
- Threaded comments and internal notes
- Budget vs actual variance analysis
- Entity comparison (side-by-side)
- Waterfall charts (P&L bridges, NAV attribution)
- Currency revaluation with translation adjustments
- Audit trail export and audit-ready package
- Reporting currency switching
- Segment reporting (business segment, geography, custom)
- Minority interest and NCI tracking
- KPI tracking with targets, trends, and threshold alerts
- Management reporting packages
- Interactive org chart with click-through
- AR/AP aging reports
- Depreciation and amortization schedules
- IFRS 16 / ASC 842 lease accounting
- XBRL and iXBRL export

### Phase 2 — Automation and integrations

Reduce manual data entry and connect to external systems.

- **Bank feed via Plaid or GoCardless.** Auto-import transactions and reconcile
  against manual entries using the existing bank_feed framework.
- **Open banking (PSD2).** EU-mandated bank connections for automatic balance and
  transaction retrieval, broader coverage than Plaid in European jurisdictions.
- **Mercury, Wise, and Revolut Business APIs.** Direct bank balance and
  transaction sync for fintech-native holding companies.
- **Xero integration.** Cover the other major accounting platform alongside
  the existing QuickBooks integration.
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
- **Bank reconciliation workflow.** Formal matching of book entries to bank
  statements with exception handling, not just raw import.
- **Period close and lock.** Close a month or quarter to prevent edits, with
  reopening requiring admin approval.
- **Import from Excel and Google Sheets.** Beyond CSV, handle `.xlsx` files with
  column mapping and validation.
- **Intercompany netting.** Net out payables and receivables across entities
  before settling, reducing the number of cross-border transfers.
- **Sweep accounts and rebalancing rules.** Define target balances per account
  and generate transfer suggestions when thresholds are breached.
- **Configurable alerts engine.** Rule-based triggers such as "alert when any
  account balance drops below X" or "when a deadline is within Y days."
- **Zapier, Make, and n8n integration.** No-code automation for non-technical
  users, connecting Holdco events and data to thousands of external services.
- **Recurring transactions.** Auto-generate repeating entries such as rent,
  subscriptions, and management fees on configurable schedules.

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
- **Tax loss harvesting.** Identify positions to sell for tax losses based on
  cost basis lots, holding periods, and wash sale rules.
- **Custom dashboards.** User-configurable widgets instead of a fixed layout.
- **FX hedging tracker.** Log forward contracts, options, and swaps against FX
  exposures the system already calculates.
- **Risk register.** Formal risk register with likelihood, impact, mitigations,
  owners, and review cycles.
- **Option pricing.** Black-Scholes and binomial models to value options and
  warrants for financial reporting.
- **Insurance coverage gap analysis.** Compare actual coverage to required
  coverage per entity and flag gaps or underinsured areas.

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
- **Withholding tax reclaim tracking.** Track treaty-based reclaims on dividends
  and interest from foreign entities with status and aging.
- **Tax provision and deferred tax.** Calculate deferred tax assets and
  liabilities per entity for financial reporting.
- **Data export for tax preparers.** Formatted exports that accountants can
  import directly into tax preparation software.
- **Intragroup service agreements.** Centralized view of all management fees,
  shared services, and cost allocation arrangements across entities.
- **Goodwill and impairment testing.** Track goodwill from acquisitions and
  annual impairment reviews with fair value calculations.
- **Fundraising and capital raising pipeline.** For fund entities actively
  raising, track commitments, soft circles, closes, and investor onboarding.
- **Multi-book accounting.** Maintain parallel books under IFRS, US GAAP, local
  GAAP, or tax basis for the same entity.

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
- **AML transaction monitoring.** Suspicious transaction detection and reporting
  beyond sanctions screening.
- **Intellectual property register.** Patents, trademarks, domains, and licenses
  per entity with renewal dates and cost tracking.
- **Contract lifecycle management.** Vendor contracts with renewal dates, SLA
  tracking, spend analytics, and expiry alerts.
- **Legal entity identifier (LEI).** Tracking and renewal alerts for LEIs
  required by financial regulators.
- **Related party transaction register.** Track and report related party
  transactions as required for audit and disclosure.
- **Conflict of interest register.** Declarations from board members and key
  personnel with review and clearance workflows.
- **Board meeting toolkit.** Agenda builder, minutes templates, action item
  extraction, and voting record management.
- **Shareholder communications.** Annual reports, investor letters, and notice
  distribution with delivery tracking.
- **Insurance claims management.** Claims workflow and loss history tracking on
  top of the existing insurance policies data.
- **Payroll and compensation tracking.** Salaries, bonuses, and benefits for key
  personnel across entities.
- **Multiple share classes.** Preferred, common, and A/B shares with different
  voting rights and liquidation preferences per entity.
- **Convertible instruments.** Track convertible notes, SAFEs, and warrants with
  conversion scenario modeling.
- **Capitalization waterfall.** Liquidation preference modeling showing who gets
  paid in what order across share classes.
- **409A and fair market value tracking.** Periodic valuations required for US
  entities issuing stock options.
- **Treasury stock and buybacks.** Share repurchase tracking and impact on cap
  table and earnings per share.
- **ESG reporting frameworks.** GRI, SASB, TCFD, and EU taxonomy alignment
  beyond the existing simple ESG scores.
- **Carbon and emissions tracking.** Scope 1, 2, and 3 emissions for
  portfolio-level ESG reporting and regulatory compliance.
- **Regulatory capital requirements.** Capital adequacy tracking for regulated
  subsidiaries such as banks or insurance companies.
- **Business continuity planning.** BCP documentation, testing schedules, and
  recovery procedures per entity.
- **Board director term tracking.** Election dates, term limits, independence
  status, and committee assignments.
- **Proxy voting.** Track voting decisions on shareholder resolutions at
  portfolio companies.
- **Whistleblower and ethics channel.** Anonymous reporting with case management
  and investigation tracking.
- **Litigation and disputes tracker.** Legal cases, status, exposure estimates,
  and legal costs per entity.
- **Bank guarantees and letters of credit.** Track issued and received guarantees
  with expiry dates, collateral, and counterparty details.

### Phase 6 — Real assets, crypto, and DeFi

Deeper support for non-traditional asset classes.

- **Real estate management.** Lease schedules, tenant tracking, rent rolls,
  maintenance costs, and property-level P&L for real estate holdings.
- **DeFi position tracking.** Staking, lending, liquidity pool positions, and
  yield farming across protocols.
- **On-chain verification.** Pull balances directly from blockchain RPCs to
  verify custodial reports.
- **Airdrop and fork tracking.** Record cost basis for received tokens.

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
- **Hardware security keys.** FIDO2 and WebAuthn support for high-security
  environments beyond TOTP-based two-factor authentication.
- **AI assistant (chat drawer and inline insights implemented).** LLM-powered
  copilot that can answer natural language questions against the structured data.
  Configurable provider (Anthropic, OpenAI) with API key and model selection in
  Settings. Persistent slide-out chat drawer accessible from any page via a
  floating button, with persisted conversations per user. Dashboard inline
  insights are live. Planned extensions: analyze uploaded documents (contracts,
  term sheets, financial statements, tax filings), summarize board packs, flag
  risks in new agreements, draft compliance narratives, and suggest optimization
  opportunities across the portfolio.
- **Document intelligence.** Automatic extraction of key terms, dates, amounts,
  and obligations from uploaded contracts and agreements using LLM parsing.
  Populate structured fields from unstructured documents and flag missing or
  expiring clauses.
- **AI-generated insights.** Periodic LLM-driven analysis of portfolio changes,
  financial trends, compliance gaps, and upcoming risks delivered as a digest
  alongside the existing email summaries.
- **Regulatory change monitoring.** Subscribe to jurisdictions and get alerts
  when relevant regulations change.
- **Multi-user real-time collaboration.** Presence indicators ("Alice is viewing
  this company") via LiveView presence.
- **Data retention policies.** GDPR and privacy compliance with automated expiry
  and deletion of stored documents and personal data.

### Phase 8 — Platform extensibility

Open the system up for custom workflows and external tools.

- **Write API (deferred).** Full read-write REST API authenticated via API keys,
  enabling programmatic data entry, external system integrations, and automation
  scripts.
- **Slack integration.** Push alerts to channels, query portfolio data with slash
  commands, and receive approval requests directly in Slack.
- **Telegram bot.** Push notifications, quick queries, and approval responses
  via Telegram for on-the-go management.
- **WhatsApp notifications.** Deadline reminders, approval requests, and critical
  alerts via WhatsApp Business API for teams that live in WhatsApp.
- **Voice call alerts.** Automated phone calls via Twilio for urgent events such
  as covenant breaches, large unauthorized transactions, or failed sanctions
  checks when chat notifications are not enough.
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
- **Offline and local-first sync.** Full offline operation with sync when
  reconnected.

### Phase 9 — Family office and philanthropy

For family offices, trusts, and multi-generational wealth.

- **Trust accounting.** Trust-specific accounting rules, beneficiary
  distributions, and trustee reporting.
- **Charitable giving and philanthropy tracking.** Donations, pledges, foundation
  grants, and tax deduction records.
- **Family governance.** Family council meetings, family charter documentation,
  and next-generation education and onboarding tracking.

## License

MIT
