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

    lines = ["| | |", "|---|---|"]
    for key, value in rows:
        lines.append(f"| **{key}** | {value} |")
    return "\n".join(lines)


def compact_table(headers: list[str], rows: list[list[str]]) -> str:
    """Build a markdown table, dropping columns that are empty in every row."""
    # Find which columns have data
    has_data = [False] * len(headers)
    for row in rows:
        for i, cell in enumerate(row):
            if cell:
                has_data[i] = True

    # Filter to non-empty columns
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
            "",
            "## Architecture",
            "",
            "| File | Purpose |",
            "|---|---|",
            "| `models.py` | Pydantic models — Company, Holding, AssetHolding, CustodianAccount |",
            "| `db.py` | SQLite layer — CRUD operations, `get_entities()`, `export_json()` |",
            "| `app.py` | Streamlit dashboard + admin panel for managing data |",
            "| `yahoo.py` | Live asset prices from Yahoo Finance |",
            "| `generate_readme.py` | Reads the database and generates this README |",
            "",
            "The `db` module exposes a Python API (`db.insert_company(...)`, `db.export_json()`, etc.)",
            "that AI agents or scripts can use directly.",
            "",
            "## Dashboard",
            "",
            "```",
            "pip install -r requirements.txt",
            "streamlit run app.py",
            "```",
            "",
            "**Dashboard tab**: corporate structure, live asset valuations, custodian details.",
            "",
            "**Companies tab**: add, edit, and delete companies and holdings.",
            "",
            "**Asset Holdings tab**: manage asset positions and custodian accounts.",
            "",
            "## Planned",
            "",
            "- QuickBooks API integration for real-time financials per entity",
        ]),
    ]

    for entity in entities:
        if isinstance(entity, Holding):
            sections.append(f"## {entity.name}")
            sections.append(details_table(entity, is_holding=True))

            if entity.subsidiaries:
                # Group subsidiaries by category
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

    return "\n\n".join(sections) + "\n"


if __name__ == "__main__":
    readme = generate()
    with open("README.md", "w") as f:
        f.write(readme)
    print("README.md generated successfully.")
