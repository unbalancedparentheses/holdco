from data import entities
from models import Company, Holding


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


def subsidiaries_table(subs: list[Company]) -> str:
    headers = [
        "Entity", "Legal Name", "Country", "Category",
        "Ownership %", "Tax ID", "Directors", "Lawyer Studio",
    ]

    rows: list[list[str]] = []
    for s in subs:
        rows.append([
            s.name,
            s.legal_name or "",
            s.country,
            s.category.value,
            f"{s.ownership_pct}%" if s.ownership_pct is not None else "",
            s.tax_id or "",
            ", ".join(s.directors) if s.directors else "",
            s.lawyer_studio or "",
        ])

    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    header_line = "| " + " | ".join(h.ljust(w) for h, w in zip(headers, widths)) + " |"
    separator = "|" + "|".join("-" * (w + 2) for w in widths) + "|"
    data_lines = []
    for row in rows:
        line = "| " + " | ".join(cell.ljust(w) for cell, w in zip(row, widths)) + " |"
        data_lines.append(line)

    return "\n".join([header_line, separator] + data_lines)


def generate() -> str:
    sections = ["# Ergodic"]

    for entity in entities:
        if isinstance(entity, Holding):
            sections.append(f"## {entity.name}")
            sections.append(details_table(entity, is_holding=True))
            if entity.subsidiaries:
                sections.append("### Subsidiaries")
                sections.append(subsidiaries_table(entity.subsidiaries))
        else:
            sections.append(f"## {entity.name}")
            sections.append(details_table(entity))

    return "\n\n".join(sections) + "\n"


if __name__ == "__main__":
    readme = generate()
    with open("README.md", "w") as f:
        f.write(readme)
    print("README.md generated successfully.")
