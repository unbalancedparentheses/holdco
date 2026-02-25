# Holdco

Open source holding company management. Track corporate structure, ownership,
asset holdings, custody, documents, tax compliance, and financials across all
your entities from a single dashboard.

Built for family offices, holding companies, and multi-entity groups that need
a simple, self-hosted way to keep everything in one place.

## Features

- **Corporate structure** — hierarchical parent/subsidiary relationships with ownership percentages
- **Asset holdings** — track positions with custodian accounts and multi-currency support
- **Live prices** — real-time asset valuations from Yahoo Finance with price history charts
- **Documents** — store contracts, articles of incorporation, and tax filings
- **Tax calendar** — deadline tracking with overdue alerts per jurisdiction
- **Financials** — revenue and expenses per entity and period with P&L aggregation
- **Ownership diagrams** — auto-generated Mermaid flowcharts with category colors
- **Audit log** — full change history of every database mutation
- **REST API** — FastAPI JSON API with 27 endpoints for programmatic access
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

All configuration lives in the database and is managed through the **Settings**
page in the admin panel:

- **App Name** — displayed in the dashboard title and API
- **Tagline** — shown in generated reports
- **Website** — included in generated reports
- **Categories** — add, edit, or remove with custom colors for Mermaid diagrams

No config files. The only environment variable is `HOLDCO_DB` (default: `holdco.db`)
to set the database path.

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
        {"name": "Sub Inc", "country": "US", "category": "Technology", "ownership_pct": 100}
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
| POST/DELETE | `/custodians/{id}` | Create or delete custodian accounts |
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
