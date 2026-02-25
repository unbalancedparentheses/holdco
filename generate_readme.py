import db
from models import Company, Holding

db.init_db()
entities = db.get_entities()
stats = db.get_stats()


def details_table(company: Company, is_holding: bool = False) -> str:
    rows: list[tuple[str, str]] = []
    if company.legal_name:
        rows.append(("Legal Name", company.legal_name))
    rows.append(("Country", company.country))
    if is_holding:
        rows.append(("Category", company.category))
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

    # Use category order from DB
    categories = db.get_categories()
    cat_order = [c["name"] for c in categories]

    cats = []
    for cat_name in cat_order:
        count = stats["by_category"].get(cat_name, 0)
        if count:
            cats.append(f"{cat_name}: {count}")
    # Include any categories in data but not in categories table
    for cat_name, count in stats["by_category"].items():
        if cat_name not in cat_order and count:
            cats.append(f"{cat_name}: {count}")
    lines.append(" | ".join(cats))

    return "\n".join(lines)


def mermaid_ownership_diagram() -> str:
    """Generate a mermaid flowchart of the corporate ownership tree."""
    lines = ["```mermaid", "graph TD"]

    all_companies = db.get_all_companies()
    categories = {c["name"]: c["color"] for c in db.get_categories()}
    id_to_name: dict[int, str] = {}
    for c in all_companies:
        safe_name = c["name"].replace('"', "'")
        node_id = f"c{c['id']}"
        id_to_name[c["id"]] = node_id
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

    # Style nodes using category colors from DB
    for c in all_companies:
        cat_color = categories.get(c["category"])
        if cat_color:
            lines.append(f"    style {id_to_name[c['id']]} fill:{cat_color}")

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
    app_name = db.get_app_name()
    tagline = db.get_setting("tagline", "")
    website = db.get_setting("website", "")

    header_parts = [f"# {app_name}"]
    if tagline:
        header_parts.append(tagline)
    if website:
        header_parts.append(f"[{website}]({website})")

    sections = [
        "\n\n".join(header_parts),
        "\n".join([
            summary_section(),
            "",
            "Tracks corporate structure, ownership, asset holdings, custody,",
            "documents, tax compliance, and financials across all entities.",
            "",
            "---",
            "",
            "This report is auto-generated from the SQLite database. Do not edit it directly.",
            "Instead, edit via the admin panel and regenerate:",
            "",
            "```",
            "streamlit run app.py        # admin panel + dashboard",
            "python generate_readme.py   # regenerate this report",
            "```",
        ]),
    ]

    # Ownership diagram
    sections.append("## Ownership Structure")
    sections.append(mermaid_ownership_diagram())

    # Entity details
    categories = db.get_categories()
    cat_order = [c["name"] for c in categories]

    for entity in entities:
        if isinstance(entity, Holding):
            sections.append(f"## {entity.name}")
            sections.append(details_table(entity, is_holding=True))

            if entity.subsidiaries:
                by_category: dict[str, list[Company]] = {}
                for sub in entity.subsidiaries:
                    by_category.setdefault(sub.category, []).append(sub)

                # Show categories in DB order first, then any remaining
                shown = set()
                for cat_name in cat_order:
                    subs = by_category.get(cat_name, [])
                    if not subs:
                        continue
                    shown.add(cat_name)
                    sections.append(f"### {cat_name} ({len(subs)})")
                    sections.append(subsidiaries_table(subs))
                    sections.extend(render_holdings(subs))

                for cat_name, subs in by_category.items():
                    if cat_name not in shown:
                        sections.append(f"### {cat_name} ({len(subs)})")
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

    return "\n\n".join(sections) + "\n"


if __name__ == "__main__":
    report = generate()
    with open("REPORT.md", "w") as f:
        f.write(report)
    print("REPORT.md generated successfully.")
