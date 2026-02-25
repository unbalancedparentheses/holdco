# Holdco

Open source holding company management system.

If you run a holding company, family office, or any multi-entity corporate
group, you need to track which companies you own, how they relate to each
other, what assets they hold, where those assets are custodied, what tax
deadlines are coming up, and what the financials look like across the whole
structure. Holdco does all of that in a single self-hosted application backed
by SQLite.

There is no SaaS, no vendor lock-in, no subscription. You own your data.
Everything runs locally or on your own server. The database file is a single
`.db` file you can back up, copy, or move anywhere.

## What It Does

**Corporate structure management.** Model your entire holding company tree —
parent companies, subsidiaries, ownership percentages, shareholders, directors,
lawyers, tax IDs, and notes. Supports any depth of nesting. Automatically
generates Mermaid ownership diagrams with color-coded categories.

**Asset holdings and custody.** Track what each entity owns — stocks, crypto,
gold, real estate, or any custom asset. Record quantities, tickers, currencies,
and link each holding to a custodian account with bank name, account number,
type, and authorized persons.

**Live price tracking.** Fetches real-time prices from Yahoo Finance for any
ticker (including BTC, ETH, gold, silver, and forex pairs). Records price
history snapshots and shows 30-day price charts on the dashboard. Calculates
total portfolio value in USD across all entities.

**Document storage.** Attach contracts, articles of incorporation, tax filings,
and agreements to any company. Track document type, URL/path, notes, and upload
date.

**Tax calendar.** Track tax filing deadlines per company and jurisdiction with
status tracking (pending, in progress, completed). Dashboard shows overdue
alerts and upcoming deadlines at a glance.

**Financial tracking.** Record revenue and expenses per entity per period with
multi-currency support. Dashboard aggregates totals and shows net P&L across
the entire structure.

**Audit log.** Every create, update, and delete operation across all tables is
logged with timestamp, action, table name, record ID, and details.

**REST API.** Full FastAPI JSON API with 27 endpoints for programmatic access.
Auto-generated Swagger UI at `/docs`. Everything you can do in the dashboard
you can do via the API.

**Report generation.** Auto-generates a markdown report (`REPORT.md`) from the
database with ownership diagrams, entity details grouped by category,
financials, tax calendar, and documents. Your real data never touches
version control.

**Configurable via web.** App name, tagline, website, and categories are all
managed through a Settings page in the admin panel. Categories have custom
colors that flow through to Mermaid diagrams. No config files to edit.

**Seed data.** Bootstrap a new instance from a JSON file. Ship your own
`seed.json` (gitignored) or use the included `seed.example.json` with demo
data. Idempotent — skips if the database already has data.

## Requirements

- **Python 3.12+**
- **Dependencies** (installed via pip or Nix):
  - [Streamlit](https://streamlit.io) >= 1.30 — dashboard and admin panel
  - [FastAPI](https://fastapi.tiangolo.com) >= 0.110 — REST API
  - [Uvicorn](https://www.uvicorn.org) >= 0.27 — ASGI server for FastAPI
  - [Pydantic](https://docs.pydantic.dev) >= 2.0 — data validation and models
  - [yfinance](https://github.com/ranaroussi/yfinance) >= 0.2 — Yahoo Finance price fetching
- **No external database** — uses SQLite (bundled with Python)

Or skip all of that and use **Docker** (only requires Docker and Docker Compose).

## Quickstart

### pip

```bash
git clone https://github.com/unbalancedparentheses/holdco.git
cd holdco
pip install -r requirements.txt
python seed.py                          # populate with demo data
streamlit run app.py                    # dashboard at http://localhost:8501
uvicorn api:app --reload                # API at http://localhost:8000
```

### Docker

```bash
git clone https://github.com/unbalancedparentheses/holdco.git
cd holdco
docker compose up
# Dashboard: http://localhost:8501
# API:       http://localhost:8000
```

Both services share a `./data/` volume for the database. Data persists across
restarts. Services have healthchecks and restart automatically.

### Nix

```bash
git clone https://github.com/unbalancedparentheses/holdco.git
cd holdco
nix develop                             # enter dev shell with all deps
python seed.py
streamlit run app.py
```

## Configuration

All configuration lives in the database and is managed through the **Settings**
page in the admin panel:

- **App Name** — displayed in the dashboard title and API title
- **Tagline** — shown in the header of generated reports
- **Website** — linked in generated reports
- **Categories** — define your own (e.g. Technology, Finance, Real Estate) with
  custom hex colors that are used in Mermaid ownership diagrams

No config files to edit. The only environment variable is `HOLDCO_DB`
(default: `holdco.db`) which sets the path to the SQLite database file. In
Docker this is set to `/app/data/holdco.db` automatically.

## Seed Data

On first run, `python seed.py` loads from `seed.json` (gitignored, your real data)
or falls back to `seed.example.json` (demo data with "Acme Holdings").

Idempotent — skips if the database already has companies.

```json
{
  "settings": {
    "app_name": "My Holdco",
    "tagline": "Family office management",
    "website": "https://example.com"
  },
  "categories": [
    {"name": "Technology", "color": "#e8f5e9"},
    {"name": "Finance", "color": "#fff3e0"}
  ],
  "companies": [
    {
      "name": "Parent Corp",
      "country": "United States",
      "category": "Holding",
      "is_holding": true,
      "shareholders": ["Alice"],
      "directors": ["Alice", "Bob"],
      "subsidiaries": [
        {
          "name": "Sub Inc",
          "country": "United States",
          "category": "Technology",
          "ownership_pct": 100,
          "holdings": [
            {
              "asset": "Bitcoin",
              "ticker": "BTC",
              "quantity": 2.5,
              "unit": "BTC",
              "custodian": {"bank": "First National Bank", "account_type": "Custody"}
            }
          ]
        }
      ]
    }
  ]
}
```

## Architecture

| File | Purpose |
|---|---|
| `models.py` | Pydantic models — Company, Holding, AssetHolding, CustodianAccount |
| `db.py` | SQLite layer — CRUD for all tables including categories and settings |
| `app.py` | Streamlit dashboard, admin panel, and settings management |
| `api.py` | FastAPI JSON API for programmatic access |
| `yahoo.py` | Live asset prices from Yahoo Finance with history tracking |
| `generate_readme.py` | Reads the database and generates `REPORT.md` |
| `seed.py` | First-run seed loader from JSON |
| `pyproject.toml` | Python package metadata and dependencies |
| `Dockerfile` | Container image (Python 3.12-slim) |
| `docker-compose.yml` | Dashboard + API services with shared data volume |
| `flake.nix` | Nix flake for reproducible dev shell and app package |

The `db` module exposes a Python API that scripts and AI agents can use directly:

```python
import db
db.init_db()
db.insert_company("Acme", "US", "Technology")
db.set_setting("app_name", "My Holdco")
db.get_categories()
db.export_json()
```

## API

JSON API at `http://localhost:8000`. Interactive docs at
[`/docs`](http://localhost:8000/docs) (Swagger UI).

| Method | Path | Description |
|---|---|---|
| GET | `/entities` | All entities with subsidiaries and holdings |
| GET/POST | `/companies` | List or create companies |
| PUT/DELETE | `/companies/{id}` | Update or delete a company |
| GET/POST | `/holdings` | List or create asset holdings |
| DELETE | `/holdings/{id}` | Delete an asset holding |
| POST | `/custodians` | Create a custodian account |
| DELETE | `/custodians/{id}` | Delete a custodian account |
| GET/POST | `/documents` | List or create documents |
| DELETE | `/documents/{id}` | Delete a document |
| GET/POST | `/tax-deadlines` | List or create tax deadlines |
| DELETE | `/tax-deadlines/{id}` | Delete a tax deadline |
| GET/POST | `/financials` | List or create financial records |
| DELETE | `/financials/{id}` | Delete a financial record |
| GET/POST | `/categories` | List or create categories |
| DELETE | `/categories/{id}` | Delete a category |
| GET | `/settings` | Get all settings |
| PUT | `/settings/{key}` | Update a setting |
| GET | `/prices/{ticker}` | Live price + 30-day history |
| GET | `/audit-log` | Recent changes |
| GET | `/stats` | Summary statistics |
| GET | `/export` | Full JSON export |

## Roadmap

### Core Platform

- [x] SQLite database with full CRUD
- [x] Streamlit admin panel (companies, holdings, custodians)
- [x] FastAPI JSON API for programmatic access
- [x] Auto-generated report with Mermaid ownership diagrams
- [x] Category-grouped subsidiaries in reports
- [x] Audit log for all database changes
- [x] Configurable categories and settings via web admin
- [x] Seed data loader from JSON
- [x] Docker and Docker Compose support
- [x] Nix flake for reproducible development
- [ ] Multi-user authentication and role-based access control
- [ ] Full-text search across all entities, documents, and notes
- [ ] Database backup/restore and migration tooling
- [ ] Data import/export from CSV/Excel
- [ ] Activity dashboard with recent changes across all tables
- [ ] Webhook notifications on changes (Slack, email, Telegram)
- [ ] Static HTML report generation for read-only sharing
- [ ] Automated database backups (scheduled SQLite snapshots)
- [ ] Real-time WebSocket updates for collaborative use
- [ ] Approval workflows (require sign-off for entity changes)
- [ ] Multi-tenant support (manage multiple holding groups)
- [ ] Custom fields per entity (user-defined attributes)
- [ ] Bulk operations (mass update categories, countries, etc.)
- [ ] Natural language query interface

### Corporate Structure & Governance

- [x] Company notes and website fields
- [x] Document storage (contracts, articles of incorporation)
- [ ] Cap table management (equity rounds, dilution, SAFE/convertible notes)
- [ ] Entity formation workflow (incorporation checklist per jurisdiction)
- [ ] Board resolution tracking and minutes
- [ ] Shareholder voting and resolution outcomes
- [ ] Power of attorney tracking (who can sign for which entity)
- [ ] Shareholder agreement management with expiry dates
- [ ] Corporate annual filing calendar (separate from tax)
- [ ] Beneficial ownership registry (UBO tracking for transparency laws)
- [ ] Corporate secretary workflows (annual returns, registered agent)
- [ ] Historical ownership timeline (track ownership changes over time)
- [ ] Key contact directory (lawyers, accountants, bankers per entity)
- [ ] Employee headcount and key personnel per subsidiary
- [ ] Regulatory license and permit tracking per entity
- [ ] KYC/AML compliance status per entity
- [ ] Entity relationship mapping for regulatory disclosures
- [ ] Entity wind-down/liquidation tracking
- [ ] Joint venture tracking with external partners
- [ ] Equity incentive plans (stock options, RSUs per subsidiary)
- [ ] M&A due diligence checklists and deal pipeline

### Financial Operations

- [x] P&L tracking (revenue/expenses per entity per period)
- [x] Multi-currency support for asset holdings
- [ ] Bank account tracking per company (operating accounts)
- [ ] Inter-company loans, transfers, and settlements
- [ ] Dividend and distribution tracking
- [ ] External debt tracking (bank loans, bonds, credit facilities)
- [ ] Cash flow tracking and forecasting
- [ ] Consolidated financial statements across subsidiaries
- [ ] Multi-currency consolidated NAV (net asset value)
- [ ] Capital contributions and equity changes log
- [ ] Budget vs. actuals tracking per entity
- [ ] Invoice management per entity
- [ ] Accounts payable and receivable aging
- [ ] FX exposure dashboard with hedging positions
- [ ] Currency hedging recommendations based on FX exposure
- [ ] Recurring transaction templates (regular dividends, management fees)
- [ ] Treasury management (cash pooling across entities)
- [ ] Loan covenants monitoring and breach alerts
- [ ] Lease accounting (IFRS 16 / ASC 842 compliance)
- [ ] Entity cost center analysis (overhead per subsidiary)
- [ ] Scenario modeling (what-if restructuring analysis)
- [ ] Automated valuation models (DCF, comparables) per subsidiary
- [ ] AI-powered anomaly detection on financials (unusual expenses, revenue drops)
- [ ] Bank feed integration (Plaid/Open Banking)
- [ ] Accounting software sync (QuickBooks, Xero, FreshBooks)

### Asset Management & Portfolio

- [x] Live asset prices from Yahoo Finance
- [x] Price history tracking with snapshots
- [ ] Cost basis tracking for tax purposes
- [ ] Portfolio performance over time with charts
- [ ] Asset allocation breakdown (by type, currency, custodian)
- [ ] Automated daily/weekly price snapshot scheduler
- [ ] Benchmark comparison (S&P 500, BTC, gold)
- [ ] Real estate holdings tracking (properties, valuations, leases)
- [ ] IP and trademark portfolio per entity
- [ ] Crypto wallet address tracking and on-chain balance verification
- [ ] Tax-loss harvesting suggestions

### Tax & Compliance

- [x] Tax calendar with deadline tracking
- [ ] Automated tax deadline reminders (email/Slack)
- [ ] Tax filing status tracker with accountant assignments
- [ ] Annual compliance checklist generator per jurisdiction
- [ ] Multi-jurisdiction tax rate reference
- [ ] Transfer pricing documentation per inter-company flow
- [ ] Withholding tax tracking on cross-border payments
- [ ] FATCA/CRS reporting helper for cross-border tax obligations
- [ ] Anti-money laundering (AML) transaction monitoring
- [ ] Sanctions screening (check persons/entities against OFAC, EU, UN lists)
- [ ] Counterparty risk assessment
- [ ] ESG reporting (environmental, social, governance scores per entity)
- [ ] Data retention policies and GDPR compliance tools
- [ ] Insurance claims tracking

### Documents & Knowledge

- [ ] Document upload to S3/cloud storage
- [ ] Version history for documents
- [ ] Contract expiry alerts and renewal tracking
- [ ] Vendor and supplier contract management
- [ ] Insurance policy tracking per entity (coverage, expiry, premiums)
- [ ] Tagging and categorization for document search
- [ ] E-signature integration (DocuSign/HelloSign) for board resolutions

### Reporting & Visualization

- [ ] Export to Excel/CSV for all tables
- [ ] P&L trend charts per entity over time
- [ ] Country breakdown charts
- [ ] Asset allocation pie charts
- [ ] Ownership waterfall diagram (direct vs. indirect ownership)
- [ ] Comparison reports (year-over-year, entity-vs-entity)
- [ ] PDF generation for board packages
- [ ] Quarterly board report generator (PDF/HTML)
- [ ] Investor portal (read-only view for shareholders)
- [ ] Email digest (weekly summary of changes, upcoming deadlines)
- [ ] Regulatory report templates (annual returns per jurisdiction)
- [ ] Customizable dashboard widgets

### Integrations

- [ ] Calendar sync (Google Calendar, Outlook) for tax deadlines
- [ ] Slack/Discord bot for notifications and quick lookups

### Security & Access

- [ ] API key authentication
- [ ] Encrypted database at rest
- [ ] Row-level access control (per-entity permissions)
- [ ] Two-factor authentication

### Infrastructure

- [ ] CI/CD pipeline with test suite
- [ ] PostgreSQL support as alternative to SQLite
- [ ] API rate limiting and API key management
- [ ] S3/MinIO for document storage backend
- [ ] Prometheus metrics endpoint for monitoring
- [ ] OpenTelemetry tracing
- [ ] Terraform deployment templates
- [ ] Internationalization (multi-language UI)
- [ ] Progressive Web App / mobile-friendly UI
- [ ] Plugin/extension system for custom modules

## License

MIT
