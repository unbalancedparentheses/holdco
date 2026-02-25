# Holdco

Open source holding company management system. Track corporate structure,
ownership, asset holdings, custody, documents, tax compliance, and financials
across all your entities from a single dashboard.

## Features

- **Corporate structure** — hierarchical parent/subsidiary relationships with ownership percentages
- **Asset holdings** — track positions with custodian accounts, multi-currency support
- **Live prices** — real-time asset valuations from Yahoo Finance with price history
- **Documents** — store contracts, articles of incorporation, tax filings
- **Tax calendar** — deadline tracking with overdue alerts per jurisdiction
- **Financials** — revenue and expenses per entity and period
- **Mermaid diagrams** — auto-generated ownership structure visualizations
- **Audit log** — full change history of all database mutations
- **REST API** — FastAPI JSON API for programmatic access
- **Report generation** — auto-generated markdown report from database
- **Configurable** — app name, categories, and settings managed via web admin panel
- **Seed data** — bootstrap from JSON for quick setup

## Quickstart

### pip

```bash
pip install -r requirements.txt
python seed.py                          # populate with demo data
streamlit run app.py                    # dashboard at http://localhost:8501
uvicorn api:app --reload                # API at http://localhost:8000
```

### Docker

```bash
docker compose up
# Dashboard: http://localhost:8501
# API:       http://localhost:8000
```

### Nix

```bash
nix develop                             # enter dev shell with all deps
python seed.py
streamlit run app.py
```

## Configuration

All configuration is done through the **Settings** page in the admin panel:

- **App Name** — displayed in the dashboard title and API
- **Tagline** — shown in generated reports
- **Website** — included in generated reports
- **Categories** — add, edit, or remove categories with custom colors for Mermaid diagrams

No config files to edit. Everything lives in the database.

## Seed Data

On first run, `python seed.py` loads data from `seed.json` (gitignored, your real data)
or falls back to `seed.example.json` (demo data with "Acme Holdings").

The seed is idempotent — it skips if the database already has companies.

### Format

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
        {"name": "Sub Inc", "country": "United States", "category": "Technology", "ownership_pct": 100}
      ]
    }
  ]
}
```

## Architecture

| File | Purpose |
|---|---|
| `models.py` | Pydantic models — Company, Holding, AssetHolding, CustodianAccount |
| `db.py` | SQLite layer — CRUD for all tables, categories, settings |
| `app.py` | Streamlit dashboard + admin panel + settings management |
| `api.py` | FastAPI JSON API for programmatic access |
| `yahoo.py` | Live asset prices from Yahoo Finance with history tracking |
| `generate_readme.py` | Reads the database and generates `REPORT.md` |
| `seed.py` | First-run seed loader from JSON |

The `db` module exposes a Python API (`db.insert_company(...)`, `db.get_categories()`,
`db.get_setting(...)`, etc.) that AI agents or scripts can use directly.

## API

JSON API at `http://localhost:8000`. Full endpoint list:

| Method | Path | Description |
|---|---|---|
| GET | `/entities` | All entities with subsidiaries and holdings |
| GET | `/companies` | List all companies |
| POST | `/companies` | Create a company |
| PUT | `/companies/{id}` | Update a company |
| DELETE | `/companies/{id}` | Delete a company |
| GET | `/holdings` | List all asset holdings |
| POST | `/holdings` | Create an asset holding |
| DELETE | `/holdings/{id}` | Delete an asset holding |
| POST | `/custodians` | Create a custodian account |
| DELETE | `/custodians/{id}` | Delete a custodian account |
| GET | `/documents` | List all documents |
| POST | `/documents` | Create a document |
| DELETE | `/documents/{id}` | Delete a document |
| GET | `/tax-deadlines` | List all tax deadlines |
| POST | `/tax-deadlines` | Create a tax deadline |
| DELETE | `/tax-deadlines/{id}` | Delete a tax deadline |
| GET | `/financials` | List all financials |
| POST | `/financials` | Create a financial record |
| DELETE | `/financials/{id}` | Delete a financial record |
| GET | `/categories` | List all categories |
| POST | `/categories` | Create a category |
| DELETE | `/categories/{id}` | Delete a category |
| GET | `/settings` | Get all settings |
| PUT | `/settings/{key}` | Update a setting |
| GET | `/prices/{ticker}` | Get live price + history |
| GET | `/audit-log` | View recent changes |
| GET | `/stats` | Summary statistics |
| GET | `/export` | Full JSON export |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `HOLDCO_DB` | `holdco.db` | Path to SQLite database file |

## Roadmap

### Core Platform

- [x] SQLite database with full CRUD
- [x] Streamlit admin panel (companies, holdings, custodians)
- [x] FastAPI JSON API for programmatic access
- [x] Auto-generated report with architecture docs
- [x] Mermaid ownership structure diagram
- [x] Category-grouped subsidiaries in reports
- [x] Audit log for all database changes
- [x] Configurable categories and settings via web admin
- [x] Seed data loader from JSON
- [x] Docker and Docker Compose support
- [x] Nix flake for reproducible development
- [ ] Multi-user authentication and role-based access control
- [ ] Database backup/restore and migration tooling
- [ ] Full-text search across all entities, documents, and notes
- [ ] Webhook notifications on changes (Slack, email, Telegram)
- [ ] Static HTML report generation for read-only sharing
- [ ] Activity dashboard with recent changes across all tables
- [ ] Automated database backups (scheduled SQLite snapshots)
- [ ] Data import/export from CSV/Excel
- [ ] Real-time WebSocket updates for collaborative use
- [ ] Multi-tenant support (manage multiple holding groups)
- [ ] Custom fields per entity (user-defined attributes)
- [ ] Bulk operations (mass update categories, countries, etc.)
- [ ] Approval workflows (require sign-off for entity changes)
- [ ] Natural language query interface ("show me all companies in Germany")

### Corporate Structure & Governance

- [x] Company notes and website fields
- [x] Document storage (contracts, articles of incorporation)
- [ ] Board resolution tracking and minutes
- [ ] Power of attorney tracking (who can sign for which entity)
- [ ] Shareholder agreement management with expiry dates
- [ ] Corporate annual filing calendar (separate from tax)
- [ ] Regulatory license and permit tracking per entity
- [ ] KYC/AML compliance status per entity
- [ ] Key contact directory (lawyers, accountants, bankers per entity)
- [ ] Employee headcount and key personnel per subsidiary
- [ ] Beneficial ownership registry (UBO tracking for transparency laws)
- [ ] Corporate secretary workflows (annual returns, registered agent)
- [ ] Entity relationship mapping for regulatory disclosures
- [ ] Historical ownership timeline (track ownership changes over time)

### Financial Operations

- [x] P&L tracking (revenue/expenses per entity per period)
- [x] Multi-currency support for asset holdings
- [ ] Bank account tracking per company (operating accounts)
- [ ] Inter-company loans, transfers, and settlements
- [ ] Dividend and distribution tracking
- [ ] Capital contributions and equity changes log
- [ ] Budget vs. actuals tracking per entity
- [ ] Cash flow tracking and forecasting
- [ ] Consolidated financial statements across subsidiaries
- [ ] FX exposure dashboard with hedging positions
- [ ] Accounts payable and receivable aging
- [ ] QuickBooks/Xero API integration for real-time bookkeeping sync
- [ ] Invoice management per entity
- [ ] Multi-currency consolidated NAV (net asset value)
- [ ] Dividend yield tracking and projections
- [ ] Entity cost center analysis (overhead per subsidiary)
- [ ] Scenario modeling (what-if restructuring analysis)
- [ ] Bank feed integration (Plaid/Open Banking)
- [ ] Recurring transaction templates (regular dividends, management fees)
- [ ] Currency hedging recommendations based on FX exposure
- [ ] Automated valuation models (DCF, comparables) per subsidiary
- [ ] AI-powered anomaly detection on financials (unusual expenses, revenue drops)

### Asset Management & Portfolio

- [x] Live asset prices from Yahoo Finance
- [x] Price history tracking with snapshots
- [ ] Cost basis tracking for tax purposes
- [ ] Portfolio performance over time with charts
- [ ] Asset allocation breakdown (by type, currency, custodian)
- [ ] Real estate holdings tracking (properties, valuations, leases)
- [ ] IP and trademark portfolio per entity
- [ ] Crypto wallet address tracking and on-chain balance verification
- [ ] Automated daily/weekly price snapshot scheduler
- [ ] Benchmark comparison (S&P 500, BTC, gold)
- [ ] Tax-loss harvesting suggestions

### Tax & Compliance

- [x] Tax calendar with deadline tracking
- [ ] Automated tax deadline reminders (email/Slack)
- [ ] Multi-jurisdiction tax rate reference
- [ ] Transfer pricing documentation per inter-company flow
- [ ] Tax filing status tracker with accountant assignments
- [ ] Withholding tax tracking on cross-border payments
- [ ] Annual compliance checklist generator per jurisdiction
- [ ] Anti-money laundering (AML) transaction monitoring
- [ ] FATCA/CRS reporting helper for cross-border tax obligations

### Documents & Knowledge

- [ ] Document upload to S3/cloud storage
- [ ] Version history for documents
- [ ] Contract expiry alerts and renewal tracking
- [ ] Vendor and supplier contract management
- [ ] Insurance policy tracking per entity (coverage, expiry, premiums)
- [ ] Tagging and categorization for document search
- [ ] E-signature integration (DocuSign/HelloSign) for board resolutions

### Reporting & Visualization

- [ ] Country breakdown charts
- [ ] P&L trend charts per entity over time
- [ ] Asset allocation pie charts
- [ ] Ownership waterfall diagram (direct vs. indirect ownership)
- [ ] Quarterly board report generator (PDF/HTML)
- [ ] Customizable dashboard widgets
- [ ] Export to Excel/CSV for all tables
- [ ] Investor portal (read-only view for shareholders)
- [ ] Email digest (weekly summary of changes, upcoming deadlines)
- [ ] PDF generation for board packages
- [ ] Comparison reports (year-over-year, entity-vs-entity)
- [ ] Regulatory report templates (annual returns per jurisdiction)

### Integrations

- [ ] Accounting software sync (QuickBooks, Xero, FreshBooks)
- [ ] Calendar sync (Google Calendar, Outlook) for tax deadlines
- [ ] Slack/Discord bot for notifications and quick lookups

### Security & Access

- [ ] Encrypted database at rest
- [ ] API key authentication
- [ ] Row-level access control (per-entity permissions)
- [ ] Two-factor authentication

### Infrastructure

- [ ] PostgreSQL support as alternative to SQLite
- [ ] S3/MinIO for document storage backend
- [ ] Prometheus metrics endpoint for monitoring
- [ ] OpenTelemetry tracing
- [ ] Terraform deployment templates

## License

MIT
