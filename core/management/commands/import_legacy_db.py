"""Import data from legacy SQLite holdco.db into Django models."""

import sqlite3
from pathlib import Path

from django.core.management.base import BaseCommand

from core.models import (
    AssetHolding,
    AuditLog,
    BankAccount,
    BoardMeeting,
    Category,
    Company,
    CustodianAccount,
    Document,
    Financial,
    InsurancePolicy,
    Liability,
    PriceHistory,
    ServiceProvider,
    Setting,
    TaxDeadline,
    Transaction,
)


def _split_csv(s):
    if not s:
        return []
    return [x.strip() for x in s.split(",") if x.strip()]


class Command(BaseCommand):
    help = "Import data from legacy holdco.db SQLite database"

    def add_arguments(self, parser):
        parser.add_argument(
            "db_path",
            nargs="?",
            default="holdco.db",
            help="Path to legacy holdco.db (default: holdco.db)",
        )

    def handle(self, *args, **options):
        db_path = Path(options["db_path"])
        if not db_path.exists():
            self.stderr.write(f"Database not found: {db_path}")
            return

        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row

        # Settings
        for row in conn.execute("SELECT * FROM settings").fetchall():
            Setting.objects.update_or_create(
                key=row["key"], defaults={"value": row["value"]}
            )
        self.stdout.write(f"Imported settings.")

        # Categories
        for row in conn.execute("SELECT * FROM categories ORDER BY id").fetchall():
            Category.objects.get_or_create(
                name=row["name"], defaults={"color": row["color"] or "#e0e0e0"}
            )
        self.stdout.write(f"Imported categories.")

        # Companies — need to map old IDs to new objects
        old_to_new = {}
        # First pass: top-level companies (no parent)
        for row in conn.execute(
            "SELECT * FROM companies WHERE parent_id IS NULL ORDER BY id"
        ).fetchall():
            c = Company.objects.create(
                name=row["name"],
                legal_name=row["legal_name"],
                country=row["country"],
                category=row["category"],
                is_holding=bool(row["is_holding"]),
                ownership_pct=row["ownership_pct"],
                tax_id=row["tax_id"],
                shareholders=_split_csv(row["shareholders"]),
                directors=_split_csv(row["directors"]),
                lawyer_studio=row["lawyer_studio"],
                notes=row["notes"],
                website=row["website"],
            )
            old_to_new[row["id"]] = c

        # Second pass: subsidiaries
        for row in conn.execute(
            "SELECT * FROM companies WHERE parent_id IS NOT NULL ORDER BY id"
        ).fetchall():
            parent = old_to_new.get(row["parent_id"])
            c = Company.objects.create(
                name=row["name"],
                legal_name=row["legal_name"],
                country=row["country"],
                category=row["category"],
                is_holding=bool(row["is_holding"]),
                parent=parent,
                ownership_pct=row["ownership_pct"],
                tax_id=row["tax_id"],
                shareholders=_split_csv(row["shareholders"]),
                directors=_split_csv(row["directors"]),
                lawyer_studio=row["lawyer_studio"],
                notes=row["notes"],
                website=row["website"],
            )
            old_to_new[row["id"]] = c

        self.stdout.write(f"Imported {len(old_to_new)} companies.")

        # Asset holdings
        ah_map = {}
        for row in conn.execute("SELECT * FROM asset_holdings ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                ah = AssetHolding.objects.create(
                    company=company,
                    asset=row["asset"],
                    ticker=row["ticker"],
                    quantity=row["quantity"],
                    unit=row["unit"],
                    currency=row["currency"] or "USD",
                )
                ah_map[row["id"]] = ah
        self.stdout.write(f"Imported {len(ah_map)} asset holdings.")

        # Custodian accounts
        count = 0
        for row in conn.execute("SELECT * FROM custodian_accounts ORDER BY id").fetchall():
            ah = ah_map.get(row["asset_holding_id"])
            if ah:
                CustodianAccount.objects.create(
                    asset_holding=ah,
                    bank=row["bank"],
                    account_number=row["account_number"],
                    account_type=row["account_type"],
                    authorized_persons=_split_csv(row["authorized_persons"]),
                )
                count += 1
        self.stdout.write(f"Imported {count} custodian accounts.")

        # Documents
        count = 0
        for row in conn.execute("SELECT * FROM documents ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                Document.objects.create(
                    company=company,
                    name=row["name"],
                    doc_type=row["doc_type"],
                    url=row["url"],
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} documents.")

        # Tax deadlines
        count = 0
        for row in conn.execute("SELECT * FROM tax_deadlines ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                TaxDeadline.objects.create(
                    company=company,
                    jurisdiction=row["jurisdiction"],
                    description=row["description"],
                    due_date=row["due_date"],
                    status=row["status"] or "pending",
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} tax deadlines.")

        # Financials
        count = 0
        for row in conn.execute("SELECT * FROM financials ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                Financial.objects.create(
                    company=company,
                    period=row["period"],
                    revenue=row["revenue"] or 0,
                    expenses=row["expenses"] or 0,
                    currency=row["currency"] or "USD",
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} financials.")

        # Bank accounts
        count = 0
        for row in conn.execute("SELECT * FROM bank_accounts ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                BankAccount.objects.create(
                    company=company,
                    bank_name=row["bank_name"],
                    account_number=row["account_number"],
                    iban=row["iban"],
                    swift=row["swift"],
                    currency=row["currency"] or "USD",
                    account_type=row["account_type"] or "operating",
                    balance=row["balance"] or 0,
                    authorized_signers=_split_csv(row["authorized_signers"]),
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} bank accounts.")

        # Transactions
        count = 0
        for row in conn.execute("SELECT * FROM transactions ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                ah = ah_map.get(row["asset_holding_id"])
                Transaction.objects.create(
                    company=company,
                    transaction_type=row["transaction_type"],
                    description=row["description"],
                    amount=row["amount"],
                    currency=row["currency"] or "USD",
                    counterparty=row["counterparty"],
                    date=row["date"],
                    asset_holding=ah,
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} transactions.")

        # Liabilities
        count = 0
        for row in conn.execute("SELECT * FROM liabilities ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                Liability.objects.create(
                    company=company,
                    liability_type=row["liability_type"],
                    creditor=row["creditor"],
                    principal=row["principal"],
                    currency=row["currency"] or "USD",
                    interest_rate=row["interest_rate"],
                    maturity_date=row["maturity_date"],
                    status=row["status"] or "active",
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} liabilities.")

        # Service providers
        count = 0
        for row in conn.execute("SELECT * FROM service_providers ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                ServiceProvider.objects.create(
                    company=company,
                    role=row["role"],
                    name=row["name"],
                    firm=row["firm"],
                    email=row["email"],
                    phone=row["phone"],
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} service providers.")

        # Insurance policies
        count = 0
        for row in conn.execute("SELECT * FROM insurance_policies ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                InsurancePolicy.objects.create(
                    company=company,
                    policy_type=row["policy_type"],
                    provider=row["provider"],
                    policy_number=row["policy_number"],
                    coverage_amount=row["coverage_amount"],
                    premium=row["premium"],
                    currency=row["currency"] or "USD",
                    start_date=row["start_date"],
                    expiry_date=row["expiry_date"],
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} insurance policies.")

        # Board meetings
        count = 0
        for row in conn.execute("SELECT * FROM board_meetings ORDER BY id").fetchall():
            company = old_to_new.get(row["company_id"])
            if company:
                BoardMeeting.objects.create(
                    company=company,
                    meeting_type=row["meeting_type"] or "regular",
                    scheduled_date=row["scheduled_date"],
                    status=row["status"] or "scheduled",
                    notes=row["notes"],
                )
                count += 1
        self.stdout.write(f"Imported {count} board meetings.")

        # Price history
        count = 0
        for row in conn.execute("SELECT * FROM price_history ORDER BY id").fetchall():
            PriceHistory.objects.create(
                ticker=row["ticker"],
                price=row["price"],
                currency=row["currency"] or "USD",
            )
            count += 1
        self.stdout.write(f"Imported {count} price history records.")

        conn.close()
        self.stdout.write("Legacy import complete.")
