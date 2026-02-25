# Holdco

Open-source holding company management system built on Django.

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

**Corporate structure management.** Model your entire holding company tree —
parent companies, subsidiaries, ownership percentages, shareholders, directors,
lawyers, tax IDs, and notes. Supports any depth of nesting.

**Asset holdings and custody.** Track what each entity owns — equities, crypto,
commodities, real estate, private equity, or any custom asset. Record
quantities, tickers, currencies, asset types, and link each holding to a
custodian account with bank name, account number, type, and authorized persons.

**Live price tracking.** Fetches real-time prices from Yahoo Finance for any
ticker (including BTC, ETH, gold, silver, and forex pairs). Records price
history snapshots. Calculates total portfolio value in USD across all entities.

**Live audit log via SSE.** The dashboard streams new audit log entries in
real time using Server-Sent Events — no page refresh required. Every create,
update, and delete across all tables is logged with timestamp, action, table
name, record ID, and details.

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
and agreements to any company. Track document type, URL/path, notes, and upload
date.

**Tax calendar.** Track tax filing deadlines per company and jurisdiction with
status tracking (pending, in progress, completed). Dashboard shows upcoming
deadlines at a glance.

**Financial tracking.** Record revenue and expenses per entity per period with
multi-currency support. Dashboard aggregates totals and shows net P&L.

**Service providers.** Maintain a directory of lawyers, accountants, auditors,
bankers, tax advisors, and registered agents per entity with contact details.

**Insurance policies.** Track insurance coverage per entity — D&O, cyber,
property, professional liability. Record policy numbers, coverage amounts,
premiums, and expiry dates.

**Board meetings.** Schedule and track board meetings per entity — regular,
special, annual, and extraordinary meetings with status tracking and notes.

**Role-based access control.** Three roles — admin (full access), editor (create
and update), viewer (read-only). Roles are enforced on every API endpoint.
Authentication via django-allauth with Google OAuth support.

**REST API.** Full Django REST Framework JSON API with ~35 endpoints. Everything
you can do in the dashboard you can do via the API.

**Categories and settings.** Define your own categories (Technology, Finance,
Real Estate) with custom colors. App-wide settings managed via API or admin.

## Architecture

| Component | Technology |
|---|---|
| Web framework | Django 5 |
| REST API | Django REST Framework |
| Database | SQLite |
| Authentication | django-allauth (email + Google OAuth) |
| Admin panel | django-unfold |
| Price data | Yahoo Finance via yfinance |
| Live updates | Server-Sent Events (SSE) |
| Testing | pytest + Hypothesis (property-based) |

### Project Structure

| File / Directory | Purpose |
|---|---|
| `holdco/` | Django project (settings, URLs, middleware, WSGI) |
| `core/models.py` | All database models (Company, AssetHolding, BankAccount, etc.) |
| `core/views.py` | API views, portfolio calculation, SSE stream, dashboard |
| `core/serializers.py` | DRF serializers for all models |
| `core/permissions.py` | RBAC permission classes |
| `core/admin.py` | Unfold admin configuration with inlines |
| `core/urls.py` | API URL routing (`/api/...`) |
| `core/dashboard_urls.py` | HTML dashboard URL routing (`/`, `/company/<id>/`) |
| `core/templates/` | Django templates (dashboard, company detail) |
| `core/tests/` | Test suite (unit, e2e, property-based, fuzz) |
| `yahoo.py` | Yahoo Finance price fetching + FX rates |
| `conftest.py` | pytest fixtures (admin/editor/viewer clients) |

## Quickstart

### pip

```bash
git clone https://github.com/unbalancedparentheses/holdco.git
cd holdco
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser         # create your first admin user
python manage.py set_role <username> admin  # assign admin role
python manage.py runserver               # http://localhost:8000
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DJANGO_SECRET_KEY` | insecure dev key | Production secret key |
| `DJANGO_DEBUG` | `1` | Set `0` for production |
| `DJANGO_ALLOWED_HOSTS` | `*` | Comma-separated allowed hosts |
| `HOLDCO_DB` | `holdco.db` | Path to SQLite database file |
| `GOOGLE_CLIENT_ID` | (empty) | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | (empty) | Google OAuth client secret |

## API Endpoints

All endpoints are prefixed with `/api/`. Authentication is required on all
endpoints. Role-based permissions apply (viewer = GET only, editor = GET +
POST + PUT, admin = full access).

| Method | Path | Description |
|---|---|---|
| GET | `/api/me` | Current user info and role |
| GET/POST | `/api/companies` | List or create companies |
| PUT/DELETE | `/api/companies/{id}` | Update or delete a company |
| GET/POST | `/api/holdings` | List or create asset holdings |
| DELETE | `/api/holdings/{id}` | Delete an asset holding |
| POST | `/api/custodians` | Create a custodian account |
| DELETE | `/api/custodians/{id}` | Delete a custodian account |
| GET/POST | `/api/documents` | List or create documents |
| DELETE | `/api/documents/{id}` | Delete a document |
| GET/POST | `/api/tax-deadlines` | List or create tax deadlines |
| DELETE | `/api/tax-deadlines/{id}` | Delete a tax deadline |
| GET/POST | `/api/financials` | List or create financial records |
| DELETE | `/api/financials/{id}` | Delete a financial record |
| GET/POST | `/api/categories` | List or create categories |
| DELETE | `/api/categories/{id}` | Delete a category |
| GET | `/api/settings` | Get all settings |
| PUT | `/api/settings/{key}` | Update a setting |
| GET/POST | `/api/bank-accounts` | List or create bank accounts |
| DELETE | `/api/bank-accounts/{id}` | Delete a bank account |
| GET/POST | `/api/transactions` | List or create transactions |
| DELETE | `/api/transactions/{id}` | Delete a transaction |
| GET/POST | `/api/liabilities` | List or create liabilities |
| DELETE | `/api/liabilities/{id}` | Delete a liability |
| GET/POST | `/api/service-providers` | List or create service providers |
| DELETE | `/api/service-providers/{id}` | Delete a service provider |
| GET/POST | `/api/insurance-policies` | List or create insurance policies |
| DELETE | `/api/insurance-policies/{id}` | Delete an insurance policy |
| GET/POST | `/api/board-meetings` | List or create board meetings |
| DELETE | `/api/board-meetings/{id}` | Delete a board meeting |
| GET | `/api/portfolio` | Portfolio NAV breakdown (liquid, marketable, illiquid, liabilities) |
| GET | `/api/prices/{ticker}` | Live price + 30-day history |
| GET | `/api/audit-log` | Recent audit log entries |
| GET | `/api/audit-log/stream` | SSE stream of live audit log entries |
| GET | `/api/stats` | Summary statistics |
| GET | `/api/export` | Full JSON export |
| GET | `/api/entities` | All entities with subsidiaries and holdings |

### HTML Pages

| Path | Description |
|---|---|
| `/` | Dashboard with portfolio NAV, corporate structure, transactions, deadlines |
| `/company/{id}/` | Company detail with holdings (live prices), bank accounts, liabilities |
| `/admin/` | Django Unfold admin panel |
| `/accounts/login/` | Login (email + Google OAuth) |

## Testing

```bash
pytest                                   # run full suite
pytest core/tests/ -v                    # verbose output
pytest core/tests/test_e2e.py            # end-to-end workflows only
pytest core/tests/test_fuzz.py           # property-based / fuzz tests
```

The test suite includes:
- **End-to-end workflow tests** — full holding company lifecycle, RBAC, dashboard rendering
- **Property-based tests** — Hypothesis-generated inputs for serializer validation
- **Fuzz tests** — random data for API endpoints
- **Portfolio tests** — NAV calculation with holdings, bank accounts, liabilities
- **SSE tests** — audit log stream content-type verification

## Accounting Approach

Holdco provides practical single-entry tracking for holding company oversight:

- **BankAccount** balances serve as the cash ledger
- **AssetHolding** + **PriceHistory** serve as the investment ledger
- **Liability** tracks debt obligations
- **Transaction** records all movements with amounts, dates, and counterparties
- **AuditLog** provides full change history across all tables

This covers what a holding company dashboard needs. True double-entry accounting
(debits/credits, journal entries, chart of accounts) would be a significant
addition. For per-entity GAAP/IFRS-compliant books, external providers like
QuickBooks or Xero remain the right choice.

## Roadmap

### Core Platform

- [x] Django + DRF + SQLite
- [x] Role-based access control (admin, editor, viewer)
- [x] django-allauth authentication with Google OAuth
- [x] django-unfold admin panel
- [x] Audit log for all database changes
- [x] Live audit log via SSE
- [x] Portfolio NAV dashboard (liquid + marketable + illiquid - liabilities)
- [x] Asset type classification (equity, crypto, commodity, real_estate, private_equity, other)
- [x] Configurable categories and settings
- [x] Full JSON export
- [ ] Full-text search across all entities, documents, and notes
- [ ] Database backup/restore and migration tooling
- [ ] Data import/export from CSV/Excel
- [ ] Webhook notifications on changes (Slack, email, Telegram)
- [ ] Real-time WebSocket updates for collaborative use
- [ ] Approval workflows (require sign-off for entity changes)
- [ ] Multi-tenant support (manage multiple holding groups)
- [ ] Custom fields per entity (user-defined attributes)
- [ ] Bulk operations (mass update categories, countries, etc.)
- [ ] Natural language query interface

### Corporate Structure & Governance

- [x] Company notes and website fields
- [x] Document storage (contracts, articles of incorporation)
- [x] Board meeting schedule and tracking
- [x] Service provider directory per entity
- [ ] Cap table management (equity rounds, dilution, SAFE/convertible notes)
- [ ] Entity formation workflow (incorporation checklist per jurisdiction)
- [ ] Shareholder voting and resolution outcomes
- [ ] Power of attorney and signing authority matrix
- [ ] Corporate annual filing calendar
- [ ] Beneficial ownership registry (UBO tracking)
- [ ] Historical ownership timeline
- [ ] Employee headcount and key personnel per subsidiary
- [ ] Regulatory license and permit tracking
- [ ] KYC/AML compliance status per entity
- [ ] Entity wind-down/liquidation tracking
- [ ] Joint venture tracking with external partners
- [ ] Equity incentive plans (stock options, RSUs per subsidiary)
- [ ] M&A due diligence checklists and deal pipeline

### Financial Operations

- [x] P&L tracking (revenue/expenses per entity per period)
- [x] Multi-currency support
- [x] Bank accounts per entity with balances
- [x] Transaction history
- [x] Liabilities and debt tracking
- [ ] Double-entry accounting (journal entries, chart of accounts)
- [ ] Inter-company loans, transfers, and settlements
- [ ] Dividend and distribution tracking
- [ ] Capital contributions and distributions log
- [ ] Tax payment tracking per jurisdiction
- [ ] Cash flow tracking and forecasting
- [ ] Consolidated financial statements
- [ ] Budget vs. actuals tracking
- [ ] FX exposure dashboard with hedging positions
- [ ] Treasury management (cash pooling across entities)
- [ ] Accounting software sync (QuickBooks, Xero)
- [ ] Bank feed integration (Plaid/Open Banking)

### Asset Management & Portfolio

- [x] Live asset prices from Yahoo Finance
- [x] Price history tracking
- [x] Asset type classification
- [x] Portfolio NAV calculation
- [ ] Cost basis tracking with lot-level detail
- [ ] Unrealized and realized gains/losses
- [ ] Portfolio performance over time with charts
- [ ] Asset allocation breakdown (by type, currency, custodian, entity)
- [ ] Automated daily/weekly price snapshot scheduler
- [ ] Benchmark comparison (S&P 500, BTC, gold)
- [ ] Real estate holdings (properties, valuations, rental income)
- [ ] Private equity fund investments (capital calls, distributions, NAV)
- [ ] Crypto wallet address tracking and on-chain balance verification
- [ ] Tax-loss harvesting suggestions

### Tax & Compliance

- [x] Tax calendar with deadline tracking
- [x] Insurance policy management
- [ ] Automated tax deadline reminders
- [ ] Annual compliance checklist generator per jurisdiction
- [ ] Transfer pricing documentation
- [ ] Withholding tax tracking on cross-border payments
- [ ] FATCA/CRS reporting
- [ ] Sanctions screening (OFAC, EU, UN)
- [ ] ESG reporting
- [ ] Regulatory filing tracker per jurisdiction

### Documents & Knowledge

- [ ] Document upload to S3/cloud storage
- [ ] Version history for documents
- [ ] Contract expiry alerts and renewal tracking
- [ ] E-signature integration (DocuSign/HelloSign)

### Reporting & Visualization

- [ ] Export to Excel/CSV for all tables
- [ ] P&L trend charts per entity over time
- [ ] Asset allocation pie charts
- [ ] Ownership waterfall diagram
- [ ] PDF generation for board packages
- [ ] Investor portal (read-only view for shareholders)
- [ ] Email digest (weekly summary of changes)

### Integrations

- [ ] Calendar sync (Google Calendar, Outlook) for tax deadlines
- [ ] Slack/Discord bot for notifications

### Security & Access

- [ ] API key authentication
- [ ] Encrypted database at rest
- [ ] Row-level access control (per-entity permissions)
- [ ] Two-factor authentication

### Infrastructure

- [ ] CI/CD pipeline with test suite
- [ ] PostgreSQL support as alternative to SQLite
- [ ] Docker and Docker Compose support
- [ ] Nix flake for reproducible development
- [ ] S3/MinIO for document storage backend
- [ ] Prometheus metrics endpoint
- [ ] OpenTelemetry tracing
- [ ] Internationalization (multi-language UI)

## License

MIT
