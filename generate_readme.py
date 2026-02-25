import db
from models import Category, Company, Holding

db.init_db()
entities = db.get_entities()
stats = db.get_stats()

CATEGORY_ORDER = [Category.CODE, Category.FINANCE, Category.CULTURE, Category.CRAFT]


def details_table(company: Company, is_holding: bool = False) -> str:
    rows: list[tuple[str, str]] = []
    if company.legal_name:
        rows.append(("Legal Name", company.legal_name))
    rows.append(("Country", company.country))
    if is_holding:
        rows.append(("Category", "Holding"))
    if company.ownership_pct is not None and not is_holding:
        rows.append(("Ownership %", f"{company.ownership_pct}%"))
    if company.tax_id:
        rows.append(("Tax ID", company.tax_id))
    if company.shareholders:
        rows.append(("Shareholders", ", ".join(company.shareholders)))
    if company.directors:
        rows.append(("Directors", ", ".join(company.directors)))
    if company.lawyer_studio:
        rows.append(("Lawyer Studio", company.lawyer_studio))

    # Add notes/website from DB
    db_row = db.get_company_by_name(company.name)
    if db_row:
        if db_row["website"]:
            rows.append(("Website", db_row["website"]))
        if db_row["notes"]:
            rows.append(("Notes", db_row["notes"]))

    lines = ["| | |", "|---|---|"]
    for key, value in rows:
        lines.append(f"| **{key}** | {value} |")
    return "\n".join(lines)


def compact_table(headers: list[str], rows: list[list[str]]) -> str:
    """Build a markdown table, dropping columns that are empty in every row."""
    has_data = [False] * len(headers)
    for row in rows:
        for i, cell in enumerate(row):
            if cell:
                has_data[i] = True

    kept = [i for i, has in enumerate(has_data) if has]
    if not kept:
        return ""

    h = [headers[i] for i in kept]
    filtered_rows = [[row[i] for i in kept] for row in rows]

    widths = [len(hdr) for hdr in h]
    for row in filtered_rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    header_line = "| " + " | ".join(hdr.ljust(w) for hdr, w in zip(h, widths)) + " |"
    separator = "|" + "|".join("-" * (w + 2) for w in widths) + "|"
    data_lines = []
    for row in filtered_rows:
        line = "| " + " | ".join(cell.ljust(w) for cell, w in zip(row, widths)) + " |"
        data_lines.append(line)

    return "\n".join([header_line, separator] + data_lines)


def subsidiaries_table(subs: list[Company]) -> str:
    headers = [
        "Entity", "Legal Name", "Country", "Ownership %",
        "Tax ID", "Directors", "Lawyer Studio",
    ]
    rows: list[list[str]] = []
    for s in subs:
        rows.append([
            s.name,
            s.legal_name or "",
            s.country,
            f"{s.ownership_pct}%" if s.ownership_pct is not None else "",
            s.tax_id or "",
            ", ".join(s.directors) if s.directors else "",
            s.lawyer_studio or "",
        ])
    return compact_table(headers, rows)


def holdings_table(company: Company) -> str | None:
    if not company.holdings:
        return None

    headers = ["Asset", "Ticker", "Quantity", "Unit", "Custodian Bank", "Account Type", "Authorized Persons"]
    rows: list[list[str]] = []
    for h in company.holdings:
        rows.append([
            h.asset,
            h.ticker or "",
            str(h.quantity) if h.quantity is not None else "",
            h.unit or "",
            h.custodian.bank if h.custodian else "",
            h.custodian.account_type or "" if h.custodian else "",
            ", ".join(h.custodian.authorized_persons) if h.custodian else "",
        ])
    return compact_table(headers, rows)


def render_holdings(companies: list[Company]) -> list[str]:
    sections: list[str] = []
    for c in companies:
        table = holdings_table(c)
        if table:
            sections.append(f"#### {c.name} Holdings")
            sections.append(table)
    return sections


def summary_section() -> str:
    lines = [
        f"**{stats['total_companies']}** entities across"
        f" **{len(stats['by_country'])}** countries.",
        "",
    ]

    cats = []
    for cat in CATEGORY_ORDER:
        count = stats["by_category"].get(cat.value, 0)
        if count:
            cats.append(f"{cat.value}: {count}")
    holding_count = stats["by_category"].get("Holding", 0)
    if holding_count:
        cats.append(f"Holding: {holding_count}")
    lines.append(" | ".join(cats))

    return "\n".join(lines)


def mermaid_ownership_diagram() -> str:
    """Generate a mermaid flowchart of the corporate ownership tree."""
    lines = ["```mermaid", "graph TD"]

    all_companies = db.get_all_companies()
    id_to_name: dict[int, str] = {}
    for c in all_companies:
        safe_name = c["name"].replace('"', "'")
        node_id = f"c{c['id']}"
        id_to_name[c["id"]] = node_id

        if c["is_holding"]:
            lines.append(f'    {node_id}["{safe_name}"]')
        else:
            lines.append(f'    {node_id}["{safe_name}"]')

    # Add edges
    for c in all_companies:
        if c["parent_id"] and c["parent_id"] in id_to_name:
            parent_node = id_to_name[c["parent_id"]]
            child_node = id_to_name[c["id"]]
            pct = f" {c['ownership_pct']}%" if c["ownership_pct"] is not None else ""
            if pct:
                lines.append(f"    {parent_node} -->|{pct}| {child_node}")
            else:
                lines.append(f"    {parent_node} --> {child_node}")

    # Style holdings differently
    for c in all_companies:
        if c["is_holding"]:
            lines.append(f"    style {id_to_name[c['id']]} fill:#e1f5fe,stroke:#0288d1,stroke-width:2px")

    # Style categories
    cat_colors = {
        "Code": "fill:#e8f5e9,stroke:#388e3c",
        "Finance": "fill:#fff3e0,stroke:#f57c00",
        "Culture": "fill:#f3e5f5,stroke:#7b1fa2",
        "Craft": "fill:#fce4ec,stroke:#c62828",
    }
    for c in all_companies:
        if c["category"] in cat_colors and not c["is_holding"]:
            lines.append(f"    style {id_to_name[c['id']]} {cat_colors[c['category']]}")

    lines.append("```")
    return "\n".join(lines)


def documents_section() -> str | None:
    docs = db.get_documents()
    if not docs:
        return None

    headers = ["Company", "Document", "Type", "Link"]
    rows = []
    for d in docs:
        link = f"[Link]({d['url']})" if d["url"] else ""
        rows.append([d["company_name"], d["name"], d["doc_type"] or "", link])

    return compact_table(headers, rows)


def tax_deadlines_section() -> str | None:
    deadlines = db.get_tax_deadlines()
    if not deadlines:
        return None

    headers = ["Company", "Jurisdiction", "Description", "Due Date", "Status"]
    rows = []
    for t in deadlines:
        rows.append([
            t["company_name"], t["jurisdiction"], t["description"],
            t["due_date"], t["status"] or "pending",
        ])

    return compact_table(headers, rows)


def financials_section() -> str | None:
    financials = db.get_financials()
    if not financials:
        return None

    headers = ["Company", "Period", "Revenue", "Expenses", "Net", "Currency"]
    rows = []
    for f in financials:
        net = (f["revenue"] or 0) - (f["expenses"] or 0)
        rows.append([
            f["company_name"], f["period"],
            f"${f['revenue']:,.0f}" if f["revenue"] else "",
            f"${f['expenses']:,.0f}" if f["expenses"] else "",
            f"${net:,.0f}" if f["revenue"] or f["expenses"] else "",
            f["currency"] or "USD",
        ])

    return compact_table(headers, rows)


def generate() -> str:
    sections = [
        "# Ergodic",
        "\n".join([
            "Corporate structure, asset holdings, and custody tracking for the Ergodic group.",
            "",
            summary_section(),
            "",
            "---",
            "",
            "This README is auto-generated from the SQLite database. Do not edit it directly.",
            "Instead, edit via the admin panel and regenerate:",
            "",
            "```",
            "streamlit run app.py      # admin panel + dashboard",
            "python generate_readme.py  # regenerate this file",
            "```",
        ]),
    ]

    # Ownership diagram
    sections.append("## Ownership Structure")
    sections.append(mermaid_ownership_diagram())

    # Architecture
    sections.append("\n".join([
        "## Architecture",
        "",
        "| File | Purpose |",
        "|---|---|",
        "| `models.py` | Pydantic models — Company, Holding, AssetHolding, CustodianAccount |",
        "| `db.py` | SQLite layer — CRUD operations, `get_entities()`, `export_json()` |",
        "| `app.py` | Streamlit dashboard + admin panel for managing data |",
        "| `yahoo.py` | Live asset prices from Yahoo Finance with history tracking |",
        "| `api.py` | FastAPI JSON API for programmatic access |",
        "| `generate_readme.py` | Reads the database and generates this README |",
        "",
        "The `db` module exposes a Python API (`db.insert_company(...)`, `db.export_json()`, etc.)",
        "that AI agents or scripts can use directly.",
    ]))

    # Dashboard
    sections.append("\n".join([
        "## Dashboard",
        "",
        "```",
        "pip install -r requirements.txt",
        "streamlit run app.py",
        "```",
        "",
        "**Dashboard**: corporate structure, live asset valuations, category filters, price history charts.",
        "",
        "**Companies**: add, edit, and delete companies with notes, websites, and documents.",
        "",
        "**Asset Holdings**: manage asset positions, custodian accounts, multi-currency support.",
        "",
        "**Tax Calendar**: track filing deadlines and compliance status per jurisdiction.",
        "",
        "**Financials**: revenue and expenses per entity and period.",
        "",
        "**Audit Log**: full change history of all database mutations.",
    ]))

    # API
    sections.append("\n".join([
        "## API",
        "",
        "```",
        "uvicorn api:app --reload",
        "```",
        "",
        "JSON API at `http://localhost:8000`. Endpoints:",
        "",
        "| Method | Path | Description |",
        "|---|---|---|",
        "| GET | `/entities` | All entities with subsidiaries and holdings |",
        "| GET | `/companies` | List all companies |",
        "| POST | `/companies` | Create a company |",
        "| PUT | `/companies/{id}` | Update a company |",
        "| DELETE | `/companies/{id}` | Delete a company |",
        "| GET | `/holdings` | List all asset holdings |",
        "| POST | `/holdings` | Create an asset holding |",
        "| DELETE | `/holdings/{id}` | Delete an asset holding |",
        "| GET | `/documents` | List all documents |",
        "| POST | `/documents` | Create a document |",
        "| DELETE | `/documents/{id}` | Delete a document |",
        "| GET | `/tax-deadlines` | List all tax deadlines |",
        "| POST | `/tax-deadlines` | Create a tax deadline |",
        "| DELETE | `/tax-deadlines/{id}` | Delete a tax deadline |",
        "| GET | `/financials` | List all financials |",
        "| POST | `/financials` | Create a financial record |",
        "| DELETE | `/financials/{id}` | Delete a financial record |",
        "| GET | `/prices/{ticker}` | Get live price + history |",
        "| GET | `/audit-log` | View recent changes |",
        "| GET | `/stats` | Summary statistics |",
        "| GET | `/export` | Full JSON export |",
    ]))

    # Entity details
    for entity in entities:
        if isinstance(entity, Holding):
            sections.append(f"## {entity.name}")
            sections.append(details_table(entity, is_holding=True))

            if entity.subsidiaries:
                by_category: dict[Category, list[Company]] = {}
                for sub in entity.subsidiaries:
                    by_category.setdefault(sub.category, []).append(sub)

                for cat in CATEGORY_ORDER:
                    subs = by_category.get(cat, [])
                    if not subs:
                        continue
                    sections.append(f"### {cat.value} ({len(subs)})")
                    sections.append(subsidiaries_table(subs))
                    sections.extend(render_holdings(subs))

            holdings_section = holdings_table(entity)
            if holdings_section:
                sections.append(f"### {entity.name} Holdings")
                sections.append(holdings_section)
        else:
            sections.append(f"## {entity.name}")
            sections.append(details_table(entity))
            holdings_section = holdings_table(entity)
            if holdings_section:
                sections.append("### Holdings")
                sections.append(holdings_section)

    # Documents
    docs_table = documents_section()
    if docs_table:
        sections.append("## Documents")
        sections.append(docs_table)

    # Tax Calendar
    tax_table = tax_deadlines_section()
    if tax_table:
        sections.append("## Tax Calendar")
        sections.append(tax_table)

    # Financials
    fin_table = financials_section()
    if fin_table:
        sections.append("## Financials")
        sections.append(fin_table)

    # Roadmap
    sections.append("\n".join([
        "## Roadmap",
        "",
        "- [x] SQLite database with full CRUD",
        "- [x] Streamlit admin panel (companies, holdings, custodians)",
        "- [x] Live asset prices from Yahoo Finance",
        "- [x] Mermaid ownership structure diagram",
        "- [x] Category-grouped subsidiaries in README",
        "- [x] Company notes and website fields",
        "- [x] Document storage (contracts, articles of incorporation)",
        "- [x] Tax calendar with deadline tracking",
        "- [x] P&L tracking (revenue/expenses per entity per period)",
        "- [x] Price history tracking with snapshots",
        "- [x] Multi-currency support for asset holdings",
        "- [x] Audit log for all database changes",
        "- [x] FastAPI JSON API for programmatic access",
        "- [x] Auto-generated README with architecture docs",
        "- [ ] QuickBooks API integration for real-time financials",
        "- [ ] Automated tax deadline reminders (email/Slack)",
        "- [ ] Multi-user authentication for admin panel",
        "- [ ] Document upload to S3/cloud storage",
        "- [ ] Portfolio performance over time charts",
        "- [ ] Budget vs. actuals tracking",
        "- [ ] Inter-company transaction tracking",
        "- [ ] Dividend and distribution tracking",
    ]))

    return "\n\n".join(sections) + "\n"


if __name__ == "__main__":
    readme = generate()
    with open("README.md", "w") as f:
        f.write(readme)
    print("README.md generated successfully.")
