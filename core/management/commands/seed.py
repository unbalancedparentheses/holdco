"""Seed the database from seed.json or seed.example.json.

Idempotent: skips if the database already has companies.
"""

import json
from pathlib import Path

from django.core.management.base import BaseCommand

from core.models import (
    AssetHolding,
    BankAccount,
    BoardMeeting,
    Category,
    Company,
    CustodianAccount,
    InsurancePolicy,
    Liability,
    ServiceProvider,
    Setting,
    Transaction,
)


def load_seed_data() -> dict:
    base = Path(__file__).resolve().parent.parent.parent.parent
    seed_file = base / "seed.json"
    if not seed_file.exists():
        seed_file = base / "seed.example.json"
    if not seed_file.exists():
        return {}
    with open(seed_file) as f:
        return json.load(f)


def _seed_holdings(company: Company, holdings: list[dict]) -> None:
    for h in holdings:
        ah = AssetHolding.objects.create(
            company=company,
            asset=h["asset"],
            ticker=h.get("ticker"),
            quantity=h.get("quantity"),
            unit=h.get("unit"),
            currency=h.get("currency", "USD"),
        )
        custodian = h.get("custodian")
        if custodian:
            CustodianAccount.objects.create(
                asset_holding=ah,
                bank=custodian["bank"],
                account_number=custodian.get("account_number"),
                account_type=custodian.get("account_type"),
                authorized_persons=custodian.get("authorized_persons", []),
            )


def do_seed(stdout=None) -> None:
    def out(msg):
        if stdout:
            stdout.write(msg)
        else:
            print(msg)

    if Company.objects.exists():
        out(f"Database already has {Company.objects.count()} companies. Skipping seed.")
        return

    data = load_seed_data()
    if not data:
        out("No seed file found (seed.json or seed.example.json). Skipping.")
        return

    # Settings
    for key, value in data.get("settings", {}).items():
        Setting.objects.update_or_create(key=key, defaults={"value": value})
    out(f"Seeded {len(data.get('settings', {}))} settings.")

    # Categories
    for cat in data.get("categories", []):
        Category.objects.create(name=cat["name"], color=cat.get("color", "#e0e0e0"))
    out(f"Seeded {len(data.get('categories', []))} categories.")

    # Companies
    total = 0
    for company_data in data.get("companies", []):
        parent = Company.objects.create(
            name=company_data["name"],
            country=company_data["country"],
            category=company_data.get("category", "Holding"),
            is_holding=company_data.get("is_holding", False),
            shareholders=company_data.get("shareholders", []),
            directors=company_data.get("directors", []),
            legal_name=company_data.get("legal_name"),
            tax_id=company_data.get("tax_id"),
            lawyer_studio=company_data.get("lawyer_studio"),
            notes=company_data.get("notes"),
            website=company_data.get("website"),
        )
        total += 1

        if company_data.get("holdings"):
            _seed_holdings(parent, company_data["holdings"])

        for sub in company_data.get("subsidiaries", []):
            child = Company.objects.create(
                name=sub["name"],
                country=sub["country"],
                category=sub.get("category", ""),
                parent=parent,
                ownership_pct=sub.get("ownership_pct"),
                is_holding=sub.get("is_holding", False),
                shareholders=sub.get("shareholders", []),
                directors=sub.get("directors", []),
                legal_name=sub.get("legal_name"),
                tax_id=sub.get("tax_id"),
                lawyer_studio=sub.get("lawyer_studio"),
                notes=sub.get("notes"),
                website=sub.get("website"),
            )
            total += 1

            if sub.get("holdings"):
                _seed_holdings(child, sub["holdings"])

    out(f"Seeded {total} companies.")

    # Bank accounts
    for acct in data.get("bank_accounts", []):
        company = Company.objects.filter(name=acct["company"]).first()
        if company:
            BankAccount.objects.create(
                company=company,
                bank_name=acct["bank_name"],
                account_number=acct.get("account_number"),
                iban=acct.get("iban"),
                swift=acct.get("swift"),
                currency=acct.get("currency", "USD"),
                account_type=acct.get("account_type", "operating"),
                balance=acct.get("balance", 0),
                authorized_signers=acct.get("authorized_signers", []),
                notes=acct.get("notes"),
            )
    out(f"Seeded {len(data.get('bank_accounts', []))} bank accounts.")

    # Transactions
    for txn in data.get("transactions", []):
        company = Company.objects.filter(name=txn["company"]).first()
        if company:
            Transaction.objects.create(
                company=company,
                transaction_type=txn["transaction_type"],
                description=txn["description"],
                amount=txn["amount"],
                date=txn["date"],
                currency=txn.get("currency", "USD"),
                counterparty=txn.get("counterparty"),
                notes=txn.get("notes"),
            )
    out(f"Seeded {len(data.get('transactions', []))} transactions.")

    # Liabilities
    for lia in data.get("liabilities", []):
        company = Company.objects.filter(name=lia["company"]).first()
        if company:
            Liability.objects.create(
                company=company,
                liability_type=lia["liability_type"],
                creditor=lia["creditor"],
                principal=lia["principal"],
                currency=lia.get("currency", "USD"),
                interest_rate=lia.get("interest_rate"),
                maturity_date=lia.get("maturity_date"),
                status=lia.get("status", "active"),
                notes=lia.get("notes"),
            )
    out(f"Seeded {len(data.get('liabilities', []))} liabilities.")

    # Service providers
    for sp in data.get("service_providers", []):
        company = Company.objects.filter(name=sp["company"]).first()
        if company:
            ServiceProvider.objects.create(
                company=company,
                role=sp["role"],
                name=sp["name"],
                firm=sp.get("firm"),
                email=sp.get("email"),
                phone=sp.get("phone"),
                notes=sp.get("notes"),
            )
    out(f"Seeded {len(data.get('service_providers', []))} service providers.")

    # Insurance policies
    for pol in data.get("insurance_policies", []):
        company = Company.objects.filter(name=pol["company"]).first()
        if company:
            InsurancePolicy.objects.create(
                company=company,
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
    out(f"Seeded {len(data.get('insurance_policies', []))} insurance policies.")

    # Board meetings
    for mtg in data.get("board_meetings", []):
        company = Company.objects.filter(name=mtg["company"]).first()
        if company:
            BoardMeeting.objects.create(
                company=company,
                scheduled_date=mtg["scheduled_date"],
                meeting_type=mtg.get("meeting_type", "regular"),
                status=mtg.get("status", "scheduled"),
                notes=mtg.get("notes"),
            )
    out(f"Seeded {len(data.get('board_meetings', []))} board meetings.")

    out("Seed complete.")


class Command(BaseCommand):
    help = "Seed the database from seed.json or seed.example.json"

    def handle(self, *args, **options):
        do_seed(stdout=self.stdout)
