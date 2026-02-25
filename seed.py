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


def _seed_holdings(company_name: str, holdings: list[dict]) -> None:
    """Seed asset holdings (and optional custodian) for a company."""
    company_id = db.get_company_id(company_name)
    if not company_id:
        return
    for h in holdings:
        ah_id = db.insert_asset_holding(
            company_id=company_id,
            asset=h["asset"],
            ticker=h.get("ticker"),
            quantity=h.get("quantity"),
            unit=h.get("unit"),
            currency=h.get("currency", "USD"),
        )
        custodian = h.get("custodian")
        if custodian:
            db.insert_custodian(
                asset_holding_id=ah_id,
                bank=custodian["bank"],
                account_number=custodian.get("account_number"),
                account_type=custodian.get("account_type"),
                authorized_persons=custodian.get("authorized_persons"),
            )


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

        # Seed holdings on parent company
        if company.get("holdings"):
            _seed_holdings(company["name"], company["holdings"])

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

            # Seed holdings on subsidiary
            if sub.get("holdings"):
                _seed_holdings(sub["name"], sub["holdings"])

    print(f"Seeded {total} companies.")

    # Seed bank accounts
    for acct in data.get("bank_accounts", []):
        cid = db.get_company_id(acct["company"])
        if cid:
            db.insert_bank_account(
                company_id=cid,
                bank_name=acct["bank_name"],
                account_number=acct.get("account_number"),
                iban=acct.get("iban"),
                swift=acct.get("swift"),
                currency=acct.get("currency", "USD"),
                account_type=acct.get("account_type", "operating"),
                balance=acct.get("balance", 0),
                authorized_signers=acct.get("authorized_signers"),
                notes=acct.get("notes"),
            )
    print(f"Seeded {len(data.get('bank_accounts', []))} bank accounts.")

    # Seed transactions
    for txn in data.get("transactions", []):
        cid = db.get_company_id(txn["company"])
        if cid:
            db.insert_transaction(
                company_id=cid,
                transaction_type=txn["transaction_type"],
                description=txn["description"],
                amount=txn["amount"],
                date=txn["date"],
                currency=txn.get("currency", "USD"),
                counterparty=txn.get("counterparty"),
                notes=txn.get("notes"),
            )
    print(f"Seeded {len(data.get('transactions', []))} transactions.")

    # Seed liabilities
    for lia in data.get("liabilities", []):
        cid = db.get_company_id(lia["company"])
        if cid:
            db.insert_liability(
                company_id=cid,
                liability_type=lia["liability_type"],
                creditor=lia["creditor"],
                principal=lia["principal"],
                currency=lia.get("currency", "USD"),
                interest_rate=lia.get("interest_rate"),
                maturity_date=lia.get("maturity_date"),
                status=lia.get("status", "active"),
                notes=lia.get("notes"),
            )
    print(f"Seeded {len(data.get('liabilities', []))} liabilities.")

    # Seed service providers
    for sp in data.get("service_providers", []):
        cid = db.get_company_id(sp["company"])
        if cid:
            db.insert_service_provider(
                company_id=cid,
                role=sp["role"],
                name=sp["name"],
                firm=sp.get("firm"),
                email=sp.get("email"),
                phone=sp.get("phone"),
                notes=sp.get("notes"),
            )
    print(f"Seeded {len(data.get('service_providers', []))} service providers.")

    # Seed insurance policies
    for pol in data.get("insurance_policies", []):
        cid = db.get_company_id(pol["company"])
        if cid:
            db.insert_insurance_policy(
                company_id=cid,
                policy_type=pol["policy_type"],
                provider=pol["provider"],
                policy_number=pol.get("policy_number"),
                coverage_amount=pol.get("coverage_amount"),
                premium=pol.get("premium"),
                currency=pol.get("currency", "USD"),
                start_date=pol.get("start_date"),
                expiry_date=pol.get("expiry_date"),
                notes=pol.get("notes"),
            )
    print(f"Seeded {len(data.get('insurance_policies', []))} insurance policies.")

    # Seed board meetings
    for mtg in data.get("board_meetings", []):
        cid = db.get_company_id(mtg["company"])
        if cid:
            db.insert_board_meeting(
                company_id=cid,
                scheduled_date=mtg["scheduled_date"],
                meeting_type=mtg.get("meeting_type", "regular"),
                status=mtg.get("status", "scheduled"),
                notes=mtg.get("notes"),
            )
    print(f"Seeded {len(data.get('board_meetings', []))} board meetings.")

    print("Seed complete.")


if __name__ == "__main__":
    seed()
