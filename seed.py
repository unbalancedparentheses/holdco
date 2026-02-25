"""Seed the database from seed.json (user data) or seed.example.json (demo data).

Idempotent: skips if the database already has companies.
"""

import json
from pathlib import Path

import db


def load_seed_data() -> dict:
    seed_file = Path(__file__).parent / "seed.json"
    if not seed_file.exists():
        seed_file = Path(__file__).parent / "seed.example.json"
    if not seed_file.exists():
        print("No seed file found (seed.json or seed.example.json). Skipping.")
        return {}
    with open(seed_file) as f:
        return json.load(f)


def seed() -> None:
    db.init_db()

    # Skip if DB already has data
    existing = db.get_all_companies()
    if existing:
        print(f"Database already has {len(existing)} companies. Skipping seed.")
        return

    data = load_seed_data()
    if not data:
        return

    # Seed settings
    for key, value in data.get("settings", {}).items():
        db.set_setting(key, value)
    print(f"Seeded {len(data.get('settings', {}))} settings.")

    # Seed categories
    for cat in data.get("categories", []):
        db.insert_category(cat["name"], cat.get("color", "#e0e0e0"))
    print(f"Seeded {len(data.get('categories', []))} categories.")

    # Seed companies
    total = 0
    for company in data.get("companies", []):
        parent_id = db.insert_company(
            name=company["name"],
            country=company["country"],
            category=company.get("category", "Holding"),
            is_holding=company.get("is_holding", False),
            shareholders=company.get("shareholders"),
            directors=company.get("directors"),
            legal_name=company.get("legal_name"),
            tax_id=company.get("tax_id"),
            lawyer_studio=company.get("lawyer_studio"),
            notes=company.get("notes"),
            website=company.get("website"),
        )
        total += 1

        for sub in company.get("subsidiaries", []):
            db.insert_company(
                name=sub["name"],
                country=sub["country"],
                category=sub.get("category", ""),
                parent_id=parent_id,
                ownership_pct=sub.get("ownership_pct"),
                is_holding=sub.get("is_holding", False),
                shareholders=sub.get("shareholders"),
                directors=sub.get("directors"),
                legal_name=sub.get("legal_name"),
                tax_id=sub.get("tax_id"),
                lawyer_studio=sub.get("lawyer_studio"),
                notes=sub.get("notes"),
                website=sub.get("website"),
            )
            total += 1

    print(f"Seeded {total} companies.")

    # Seed custodians (if present in seed data)
    for custodian in data.get("custodians", []):
        company_id = db.get_company_id(custodian["company"])
        if company_id:
            ah_id = db.insert_asset_holding(
                company_id=company_id,
                asset=custodian.get("asset", ""),
                ticker=custodian.get("ticker"),
                quantity=custodian.get("quantity"),
                unit=custodian.get("unit"),
                currency=custodian.get("currency", "USD"),
            )
            if custodian.get("bank"):
                db.insert_custodian(
                    asset_holding_id=ah_id,
                    bank=custodian["bank"],
                    account_number=custodian.get("account_number"),
                    account_type=custodian.get("account_type"),
                    authorized_persons=custodian.get("authorized_persons"),
                )

    print("Seed complete.")


if __name__ == "__main__":
    seed()
