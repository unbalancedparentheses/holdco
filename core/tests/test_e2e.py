"""
End-to-end workflow tests.

These exercise full multi-step business workflows through the API,
verifying that the system behaves correctly when operations compose.
"""

import pytest
from django.contrib.auth import get_user_model
from django.test import Client

from core.models import (
    Account,
    AnnualFiling,
    APIKey,
    ApprovalRequest,
    AssetHolding,
    AuditLog,
    BackupConfig,
    BackupLog,
    BankAccount,
    BeneficialOwner,
    BoardMeeting,
    Budget,
    CapitalContribution,
    CapTableEntry,
    Company,
    ComplianceChecklist,
    CostBasisLot,
    CryptoWallet,
    CustodianAccount,
    CustomField,
    CustomFieldValue,
    Deal,
    Dividend,
    Document,
    DocumentVersion,
    EntityPermission,
    EquityGrant,
    EquityIncentivePlan,
    ESGScore,
    FatcaReport,
    Financial,
    FundInvestment,
    InsurancePolicy,
    InterCompanyTransfer,
    JointVenture,
    JournalEntry,
    JournalLine,
    KeyPersonnel,
    Liability,
    OwnershipChange,
    PowerOfAttorney,
    RealEstateProperty,
    RegulatoryFiling,
    RegulatoryLicense,
    ServiceProvider,
    ShareholderResolution,
    TaxDeadline,
    TaxPayment,
    Transaction,
    TransferPricingDoc,
    Webhook,
    WithholdingTax,
    UserRole,
)

JSON = "application/json"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _post(client, url, data):
    return client.post(url, data, content_type=JSON)


def _put(client, url, data):
    return client.put(url, data, content_type=JSON)


# ---------------------------------------------------------------------------
# Full holding-company hierarchy lifecycle
# ---------------------------------------------------------------------------


class TestHoldingCompanyLifecycle:
    """Create a holding → subsidiaries → assets → custodians, verify
    everything round-trips through export, then cascade-delete."""

    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def _create_company(self, **kw):
        defaults = {"name": "Co", "country": "US", "category": "T"}
        defaults.update(kw)
        r = _post(self.c, "/api/companies", defaults)
        assert r.status_code == 201
        return r.json()["id"]

    def test_full_hierarchy(self):
        # 1. Create holding
        hold_id = self._create_company(
            name="Alpha Holdings", country="US", category="Holding", is_holding=True
        )

        # 2. Create two subsidiaries
        sub1_id = self._create_company(
            name="Alpha Tech", country="US", category="Tech", parent_id=hold_id, ownership_pct=100
        )
        sub2_id = self._create_company(
            name="Alpha Finance", country="UK", category="Finance", parent_id=hold_id, ownership_pct=80
        )

        # 3. Add asset holdings to each subsidiary
        r = _post(self.c, "/api/holdings", {
            "company_id": sub1_id, "asset": "Bitcoin", "ticker": "BTC",
            "quantity": 10, "unit": "BTC", "currency": "USD",
        })
        assert r.status_code == 201
        btc_id = r.json()["id"]

        r = _post(self.c, "/api/holdings", {
            "company_id": sub2_id, "asset": "Gold", "ticker": "GC=F",
            "quantity": 100, "unit": "oz", "currency": "USD",
        })
        assert r.status_code == 201
        gold_id = r.json()["id"]

        # 4. Attach custodian to BTC
        r = _post(self.c, "/api/custodians", {
            "asset_holding_id": btc_id, "bank": "Coinbase Custody",
            "account_number": "CB-001", "account_type": "cold",
            "authorized_persons": ["Alice", "Bob"],
        })
        assert r.status_code == 201

        # 5. Add bank accounts
        r = _post(self.c, "/api/bank-accounts", {
            "company_id": sub1_id, "bank_name": "Chase", "account_number": "1234",
            "currency": "USD", "account_type": "operating", "balance": 500000,
            "authorized_signers": ["Alice"],
        })
        assert r.status_code == 201

        # 6. Add documents, deadlines, financials, transactions
        _post(self.c, "/api/documents", {
            "company_id": sub1_id, "name": "Articles of Incorporation",
            "doc_type": "legal", "url": "https://docs.example.com/articles",
        })
        _post(self.c, "/api/tax-deadlines", {
            "company_id": sub1_id, "jurisdiction": "US-Federal",
            "description": "1120 Filing", "due_date": "2025-04-15",
            "status": "pending",
        })
        _post(self.c, "/api/financials", {
            "company_id": sub1_id, "period": "2024-Q4",
            "revenue": 1000000, "expenses": 600000, "currency": "USD",
        })
        _post(self.c, "/api/transactions", {
            "company_id": sub1_id, "transaction_type": "dividend",
            "description": "Q4 Distribution", "amount": 200000,
            "date": "2025-01-15", "currency": "USD",
        })
        _post(self.c, "/api/liabilities", {
            "company_id": sub2_id, "liability_type": "loan",
            "creditor": "HSBC", "principal": 1000000,
            "currency": "GBP", "interest_rate": 4.5,
            "maturity_date": "2028-06-30", "status": "active",
        })
        _post(self.c, "/api/service-providers", {
            "company_id": hold_id, "role": "auditor",
            "name": "Jane Doe", "firm": "KPMG", "email": "jane@kpmg.example",
        })
        _post(self.c, "/api/insurance-policies", {
            "company_id": hold_id, "policy_type": "D&O",
            "provider": "AIG", "policy_number": "DO-100",
            "coverage_amount": 10000000, "premium": 50000,
            "currency": "USD", "start_date": "2025-01-01", "expiry_date": "2026-01-01",
        })
        _post(self.c, "/api/board-meetings", {
            "company_id": hold_id, "meeting_type": "annual",
            "scheduled_date": "2025-06-15", "status": "scheduled",
        })

        # 7. Verify export endpoint returns full structure
        r = self.c.get("/api/export")
        assert r.status_code == 200
        data = r.json()

        entity_names = [e["name"] for e in data["entities"]]
        assert "Alpha Holdings" in entity_names

        holding_entity = next(e for e in data["entities"] if e["name"] == "Alpha Holdings")
        sub_names = [s["name"] for s in holding_entity["subsidiaries"]]
        assert "Alpha Tech" in sub_names
        assert "Alpha Finance" in sub_names

        assert len(data["documents"]) >= 1
        assert len(data["tax_deadlines"]) >= 1
        assert len(data["financials"]) >= 1
        assert len(data["transactions"]) >= 1
        assert len(data["liabilities"]) >= 1
        assert len(data["service_providers"]) >= 1
        assert len(data["insurance_policies"]) >= 1
        assert len(data["board_meetings"]) >= 1

        # 8. Verify stats
        r = self.c.get("/api/stats")
        assert r.status_code == 200
        stats = r.json()
        assert stats["total_companies"] == 3
        assert stats["subsidiaries"] == 2
        assert stats["asset_holdings"] == 2

        # 9. Update a subsidiary
        r = _put(self.c, f"/api/companies/{sub1_id}", {"name": "Alpha Tech Inc."})
        assert r.status_code == 200

        r = self.c.get("/api/companies")
        names = [c["name"] for c in r.json()]
        assert "Alpha Tech Inc." in names
        assert "Alpha Tech" not in names

        # 10. Delete holding — cascades to subsidiaries and everything below
        r = self.c.delete(f"/api/companies/{hold_id}")
        assert r.status_code == 200

        assert Company.objects.count() == 0
        assert AssetHolding.objects.count() == 0
        assert CustodianAccount.objects.count() == 0
        assert BankAccount.objects.count() == 0
        assert Document.objects.count() == 0
        assert TaxDeadline.objects.count() == 0
        assert Financial.objects.count() == 0
        assert Transaction.objects.count() == 0
        assert Liability.objects.count() == 0
        assert ServiceProvider.objects.count() == 0
        assert InsurancePolicy.objects.count() == 0
        assert BoardMeeting.objects.count() == 0


# ---------------------------------------------------------------------------
# RBAC end-to-end: three users, one workflow
# ---------------------------------------------------------------------------


class TestRbacWorkflow:
    """Admin creates data, editor modifies it, viewer can only read."""

    def test_three_role_workflow(self, admin_client, editor_client, viewer_client):
        # Admin creates a company
        r = _post(admin_client, "/api/companies", {
            "name": "Gamma Corp", "country": "DE", "category": "Manufacturing",
        })
        assert r.status_code == 201
        cid = r.json()["id"]

        # Editor can update it
        r = _put(editor_client, f"/api/companies/{cid}", {"name": "Gamma GmbH"})
        assert r.status_code == 200

        # Viewer sees the updated name
        r = viewer_client.get("/api/companies")
        assert r.status_code == 200
        assert r.json()[0]["name"] == "Gamma GmbH"

        # Viewer cannot create child entities
        r = _post(viewer_client, "/api/holdings", {
            "company_id": cid, "asset": "Silver",
        })
        assert r.status_code == 403

        # Editor can create child entities
        r = _post(editor_client, "/api/holdings", {
            "company_id": cid, "asset": "Silver",
        })
        assert r.status_code == 201
        hid = r.json()["id"]

        # Editor cannot delete
        r = editor_client.delete(f"/api/holdings/{hid}")
        assert r.status_code == 403

        # Admin can delete
        r = admin_client.delete(f"/api/holdings/{hid}")
        assert r.status_code == 200

        # Admin deletes the company
        r = admin_client.delete(f"/api/companies/{cid}")
        assert r.status_code == 200
        assert admin_client.get("/api/companies").json() == []


# ---------------------------------------------------------------------------
# Dashboard / HTML pages with populated data
# ---------------------------------------------------------------------------


class TestDashboardE2E:
    """Verify HTML pages render without error when data exists."""

    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {
            "name": "DashCo", "country": "US", "category": "Tech", "is_holding": True,
        })
        self.cid = r.json()["id"]
        _post(self.c, "/api/holdings", {"company_id": self.cid, "asset": "ETH", "ticker": "ETH"})
        _post(self.c, "/api/bank-accounts", {
            "company_id": self.cid, "bank_name": "SVB", "currency": "USD", "balance": 100000,
        })
        _post(self.c, "/api/transactions", {
            "company_id": self.cid, "transaction_type": "deposit",
            "description": "Funding", "amount": 100000, "date": "2025-01-01",
        })
        _post(self.c, "/api/tax-deadlines", {
            "company_id": self.cid, "jurisdiction": "US",
            "description": "Q1 Filing", "due_date": "2025-04-15", "status": "pending",
        })
        _post(self.c, "/api/liabilities", {
            "company_id": self.cid, "liability_type": "loan",
            "creditor": "Bank", "principal": 50000, "currency": "USD", "status": "active",
        })
        _post(self.c, "/api/service-providers", {
            "company_id": self.cid, "role": "lawyer", "name": "Bob",
        })
        _post(self.c, "/api/insurance-policies", {
            "company_id": self.cid, "policy_type": "liability",
            "provider": "Allianz", "expiry_date": "2026-12-31",
        })
        _post(self.c, "/api/board-meetings", {
            "company_id": self.cid, "scheduled_date": "2025-03-01", "status": "scheduled",
        })

    def test_dashboard_renders(self):
        r = self.c.get("/")
        assert r.status_code == 200
        assert b"DashCo" in r.content

    def test_company_detail_renders(self):
        r = self.c.get(f"/company/{self.cid}/")
        assert r.status_code == 200
        assert b"DashCo" in r.content
        assert b"ETH" in r.content


# ---------------------------------------------------------------------------
# Audit trail integrity
# ---------------------------------------------------------------------------


class TestAuditTrailE2E:
    """Verify the audit log captures a full create-update-delete lifecycle."""

    def test_audit_captures_lifecycle(self, admin_client):
        # Create
        r = _post(admin_client, "/api/companies", {
            "name": "AuditMe", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        # Update
        _put(admin_client, f"/api/companies/{cid}", {"name": "AuditMe2"})

        # Delete
        admin_client.delete(f"/api/companies/{cid}")

        r = admin_client.get("/api/audit-log")
        entries = r.json()
        company_entries = [e for e in entries if e["table_name"] == "core_company"]

        actions = [e["action"] for e in company_entries]
        assert "insert" in actions
        assert "update" in actions
        assert "delete" in actions


# ---------------------------------------------------------------------------
# Categories + settings lifecycle
# ---------------------------------------------------------------------------


class TestCategorySettingsE2E:
    """Categories and settings are global (not per-company). Verify full cycle."""

    def test_categories_lifecycle(self, admin_client):
        # Create multiple
        ids = []
        for name, color in [("Tech", "#0000ff"), ("Finance", "#00ff00"), ("Legal", "#ff0000")]:
            r = _post(admin_client, "/api/categories", {"name": name, "color": color})
            assert r.status_code == 201
            ids.append(r.json()["id"])

        # List
        r = admin_client.get("/api/categories")
        assert len(r.json()) == 3

        # Delete middle one
        admin_client.delete(f"/api/categories/{ids[1]}")
        r = admin_client.get("/api/categories")
        names = [c["name"] for c in r.json()]
        assert "Finance" not in names
        assert len(names) == 2

    def test_settings_overwrite(self, admin_client):
        _put(admin_client, "/api/settings/theme", {"value": "dark"})
        _put(admin_client, "/api/settings/theme", {"value": "light"})
        _put(admin_client, "/api/settings/currency", {"value": "EUR"})

        r = admin_client.get("/api/settings")
        data = r.json()
        assert data["theme"] == "light"
        assert data["currency"] == "EUR"


# ---------------------------------------------------------------------------
# /api/me consistency
# ---------------------------------------------------------------------------


@pytest.mark.django_db
def test_me_reflects_role_changes():
    """If a user's role is changed, /api/me reflects it immediately."""
    User = get_user_model()
    user = User.objects.create_user(username="chameleon", password="pass")
    role = UserRole.objects.create(user=user, role="viewer")

    client = Client()
    client.force_login(user)

    assert client.get("/api/me").json()["role"] == "viewer"

    role.role = "editor"
    role.save()
    assert client.get("/api/me").json()["role"] == "editor"

    role.role = "admin"
    role.save()
    assert client.get("/api/me").json()["role"] == "admin"


# ---------------------------------------------------------------------------
# Concurrent-ish operations (sequential but tests isolation)
# ---------------------------------------------------------------------------


class TestIsolation:
    """Verify that operations on one company don't affect another."""

    def test_delete_one_company_preserves_other(self, admin_client):
        r1 = _post(admin_client, "/api/companies", {"name": "A", "country": "US", "category": "T"})
        r2 = _post(admin_client, "/api/companies", {"name": "B", "country": "US", "category": "T"})
        a_id = r1.json()["id"]
        b_id = r2.json()["id"]

        # Add holdings to both
        _post(admin_client, "/api/holdings", {"company_id": a_id, "asset": "X"})
        _post(admin_client, "/api/holdings", {"company_id": b_id, "asset": "Y"})

        # Delete A
        admin_client.delete(f"/api/companies/{a_id}")

        # B's holding survives
        r = admin_client.get("/api/holdings")
        holdings = r.json()
        assert len(holdings) == 1
        assert holdings[0]["asset"] == "Y"

    def test_many_companies_crud(self, admin_client):
        """Create 50 companies, verify list, delete all."""
        ids = []
        for i in range(50):
            r = _post(admin_client, "/api/companies", {
                "name": f"Co-{i}", "country": "US", "category": "T",
            })
            assert r.status_code == 201
            ids.append(r.json()["id"])

        r = admin_client.get("/api/companies")
        assert len(r.json()) == 50

        for cid in ids:
            admin_client.delete(f"/api/companies/{cid}")

        assert admin_client.get("/api/companies").json() == []


# ---------------------------------------------------------------------------
# Portfolio endpoint
# ---------------------------------------------------------------------------


class TestPortfolioEndpoint:
    """Verify the portfolio API returns correct NAV breakdown."""

    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_portfolio_empty(self):
        """No data → all zeros."""
        r = self.c.get("/api/portfolio")
        assert r.status_code == 200
        data = r.json()
        assert data["liquid"] == 0
        assert data["marketable"] == 0
        assert data["illiquid"] == 0
        assert data["liabilities"] == 0
        assert data["nav"] == 0
        assert data["currency"] == "USD"

    def test_portfolio_endpoint_returns_nav(self):
        """Create companies, holdings, bank accounts, liabilities → verify NAV."""
        # Create company
        r = _post(self.c, "/api/companies", {
            "name": "Portfolio Co", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        # Bank account → liquid = 100,000
        _post(self.c, "/api/bank-accounts", {
            "company_id": cid, "bank_name": "Chase",
            "currency": "USD", "balance": 100000,
        })

        # Illiquid holding (no ticker) → illiquid = qty * 1 = 500000
        _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "Office Building",
            "quantity": 500000, "currency": "USD",
            "asset_type": "real_estate",
        })

        # Liability → 50,000
        _post(self.c, "/api/liabilities", {
            "company_id": cid, "liability_type": "loan",
            "creditor": "Bank", "principal": 50000,
            "currency": "USD", "status": "active",
        })

        r = self.c.get("/api/portfolio")
        assert r.status_code == 200
        data = r.json()

        assert data["liquid"] == 100000
        assert data["illiquid"] == 500000
        assert data["liabilities"] == 50000
        # NAV = liquid + marketable + illiquid - liabilities
        expected_nav = 100000 + data["marketable"] + 500000 - 50000
        assert data["nav"] == expected_nav
        assert "real_estate" in data["by_asset_type"]


# ---------------------------------------------------------------------------
# Asset type field
# ---------------------------------------------------------------------------


class TestAssetTypeField:
    """Verify asset_type field round-trips correctly."""

    def test_asset_type_field(self, admin_client):
        r = _post(admin_client, "/api/companies", {
            "name": "TypeCo", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        # Create with explicit asset_type
        r = _post(admin_client, "/api/holdings", {
            "company_id": cid, "asset": "Bitcoin", "ticker": "BTC",
            "quantity": 5, "currency": "USD", "asset_type": "crypto",
        })
        assert r.status_code == 201
        hid = r.json()["id"]

        # Verify it round-trips
        r = admin_client.get("/api/holdings")
        holding = next(h for h in r.json() if h["id"] == hid)
        assert holding["asset_type"] == "crypto"

    def test_asset_type_defaults_to_other(self, admin_client):
        r = _post(admin_client, "/api/companies", {
            "name": "DefaultCo", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        r = _post(admin_client, "/api/holdings", {
            "company_id": cid, "asset": "Something",
        })
        assert r.status_code == 201
        hid = r.json()["id"]

        r = admin_client.get("/api/holdings")
        holding = next(h for h in r.json() if h["id"] == hid)
        assert holding["asset_type"] == "other"


# ---------------------------------------------------------------------------
# SSE audit log stream
# ---------------------------------------------------------------------------


class TestSSEAuditStream:
    """Verify the SSE endpoint returns correct content-type and behavior."""

    def test_sse_stream_returns_event_stream(self, admin_client):
        r = admin_client.get("/api/audit-log/stream")
        assert r.status_code == 200
        assert "text/event-stream" in r["Content-Type"]

    def test_sse_stream_requires_auth(self):
        """Unauthenticated users should be redirected to login."""
        c = Client()
        r = c.get("/api/audit-log/stream")
        assert r.status_code == 302
        assert "/accounts/login/" in r.url

    def test_sse_no_cache_headers(self, admin_client):
        """SSE responses must include no-cache header."""
        r = admin_client.get("/api/audit-log/stream")
        assert r["Cache-Control"] == "no-cache"


# ---------------------------------------------------------------------------
# Multi-company portfolio with tickers
# ---------------------------------------------------------------------------


class TestMultiCompanyPortfolio:
    """Portfolio tracks holdings with tickers across multiple companies."""

    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_portfolio_multi_company_aggregation(self):
        """Holdings and bank accounts across multiple companies sum correctly."""
        # Create two companies
        r = _post(self.c, "/api/companies", {
            "name": "Alpha Corp", "country": "US", "category": "Tech",
        })
        alpha_id = r.json()["id"]

        r = _post(self.c, "/api/companies", {
            "name": "Beta Ltd", "country": "UK", "category": "Finance",
        })
        beta_id = r.json()["id"]

        # Bank accounts in both
        _post(self.c, "/api/bank-accounts", {
            "company_id": alpha_id, "bank_name": "Chase",
            "currency": "USD", "balance": 200000,
        })
        _post(self.c, "/api/bank-accounts", {
            "company_id": beta_id, "bank_name": "HSBC",
            "currency": "USD", "balance": 300000,
        })

        # Illiquid holdings in both companies
        _post(self.c, "/api/holdings", {
            "company_id": alpha_id, "asset": "Office",
            "quantity": 1000000, "currency": "USD",
            "asset_type": "real_estate",
        })
        _post(self.c, "/api/holdings", {
            "company_id": beta_id, "asset": "Warehouse",
            "quantity": 750000, "currency": "USD",
            "asset_type": "real_estate",
        })

        # Liabilities in one company
        _post(self.c, "/api/liabilities", {
            "company_id": alpha_id, "liability_type": "mortgage",
            "creditor": "Chase", "principal": 500000,
            "currency": "USD", "status": "active",
        })

        r = self.c.get("/api/portfolio")
        assert r.status_code == 200
        data = r.json()

        # liquid = 200k + 300k = 500k
        assert data["liquid"] == 500000
        # illiquid = 1M + 750k = 1.75M
        assert data["illiquid"] == 1750000
        # liabilities = 500k
        assert data["liabilities"] == 500000
        # NAV = 500k + 0 + 1.75M - 500k = 1.75M
        assert data["nav"] == 500000 + data["marketable"] + 1750000 - 500000

        # per_company should have both companies
        assert len(data["per_company"]) == 2

    def test_portfolio_paid_liabilities_excluded(self):
        """Paid/settled liabilities should not count against NAV."""
        r = _post(self.c, "/api/companies", {
            "name": "Gamma Inc", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        _post(self.c, "/api/bank-accounts", {
            "company_id": cid, "bank_name": "BoA",
            "currency": "USD", "balance": 100000,
        })

        # Active liability — should be counted
        _post(self.c, "/api/liabilities", {
            "company_id": cid, "liability_type": "loan",
            "creditor": "Bank A", "principal": 30000,
            "currency": "USD", "status": "active",
        })

        # Paid liability — should NOT be counted
        _post(self.c, "/api/liabilities", {
            "company_id": cid, "liability_type": "loan",
            "creditor": "Bank B", "principal": 50000,
            "currency": "USD", "status": "paid",
        })

        r = self.c.get("/api/portfolio")
        data = r.json()
        assert data["liabilities"] == 30000
        assert data["nav"] == 100000 - 30000  # 70000

    def test_portfolio_mixed_asset_types(self):
        """Portfolio breakdown by asset_type covers all types."""
        r = _post(self.c, "/api/companies", {
            "name": "Diversified Co", "country": "US", "category": "Multi",
        })
        cid = r.json()["id"]

        for asset_type, asset_name, qty in [
            ("equity", "AAPL Shares", 10000),
            ("crypto", "BTC Holdings", 50000),
            ("commodity", "Gold Bars", 100000),
            ("real_estate", "Building", 500000),
            ("private_equity", "Fund LP", 200000),
            ("other", "Art Collection", 75000),
        ]:
            _post(self.c, "/api/holdings", {
                "company_id": cid, "asset": asset_name,
                "quantity": qty, "currency": "USD",
                "asset_type": asset_type,
            })

        r = self.c.get("/api/portfolio")
        data = r.json()

        # All 6 asset types present in breakdown
        assert len(data["by_asset_type"]) == 6
        for at in ["equity", "crypto", "commodity", "real_estate", "private_equity", "other"]:
            assert at in data["by_asset_type"]

    def test_portfolio_tickers_across_companies(self):
        """Same ticker held by multiple companies both contribute to marketable."""
        r = _post(self.c, "/api/companies", {
            "name": "Fund A", "country": "US", "category": "Finance",
        })
        fund_a = r.json()["id"]

        r = _post(self.c, "/api/companies", {
            "name": "Fund B", "country": "US", "category": "Finance",
        })
        fund_b = r.json()["id"]

        # Same ticker (no live price, so it'll be illiquid, but both are tracked)
        _post(self.c, "/api/holdings", {
            "company_id": fund_a, "asset": "Apple",
            "ticker": "AAPL", "quantity": 100,
            "currency": "USD", "asset_type": "equity",
        })
        _post(self.c, "/api/holdings", {
            "company_id": fund_b, "asset": "Apple",
            "ticker": "AAPL", "quantity": 200,
            "currency": "USD", "asset_type": "equity",
        })

        r = self.c.get("/api/portfolio")
        data = r.json()
        # Both companies should appear in per_company
        assert len(data["per_company"]) == 2
        # equity should be in asset_type breakdown
        assert "equity" in data["by_asset_type"]


# ---------------------------------------------------------------------------
# Dashboard and company_detail template rendering with new features
# ---------------------------------------------------------------------------


class TestDashboardPortfolioRendering:
    """Verify dashboard renders the portfolio NAV strip correctly."""

    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {
            "name": "RendCo", "country": "US", "category": "Tech",
        })
        self.cid = r.json()["id"]
        _post(self.c, "/api/bank-accounts", {
            "company_id": self.cid, "bank_name": "Chase",
            "currency": "USD", "balance": 250000,
        })
        _post(self.c, "/api/holdings", {
            "company_id": self.cid, "asset": "Building",
            "quantity": 1000000, "currency": "USD",
            "asset_type": "real_estate",
        })

    def test_dashboard_contains_nav(self):
        r = self.c.get("/")
        assert r.status_code == 200
        assert b"Net Asset Value" in r.content
        assert b"Liquid" in r.content
        assert b"Marketable" in r.content
        assert b"Illiquid" in r.content

    def test_dashboard_contains_sse_script(self):
        r = self.c.get("/")
        assert b"EventSource" in r.content
        assert b"audit-log/stream" in r.content

    def test_company_detail_shows_asset_type(self):
        r = self.c.get(f"/company/{self.cid}/")
        assert r.status_code == 200
        assert b"real_estate" in r.content

    def test_company_detail_shows_price_columns(self):
        r = self.c.get(f"/company/{self.cid}/")
        assert r.status_code == 200
        assert b"Price" in r.content
        assert b"Value" in r.content


# ---------------------------------------------------------------------------
# Portfolio endpoint edge cases
# ---------------------------------------------------------------------------


class TestPortfolioEdgeCases:
    """Edge cases for the portfolio calculation."""

    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_portfolio_zero_quantity_holding(self):
        """A holding with quantity=0 should not affect NAV."""
        r = _post(self.c, "/api/companies", {
            "name": "ZeroCo", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "Sold Stock",
            "quantity": 0, "currency": "USD", "asset_type": "equity",
        })

        r = self.c.get("/api/portfolio")
        data = r.json()
        assert data["illiquid"] == 0
        assert data["nav"] == 0

    def test_portfolio_null_quantity_holding(self):
        """A holding with null quantity should not break the calculation."""
        r = _post(self.c, "/api/companies", {
            "name": "NullCo", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "Placeholder",
            "currency": "USD",
        })

        r = self.c.get("/api/portfolio")
        assert r.status_code == 200
        data = r.json()
        assert data["nav"] == 0

    def test_portfolio_only_liabilities(self):
        """Only liabilities → negative NAV."""
        r = _post(self.c, "/api/companies", {
            "name": "DebtCo", "country": "US", "category": "T",
        })
        cid = r.json()["id"]

        _post(self.c, "/api/liabilities", {
            "company_id": cid, "liability_type": "loan",
            "creditor": "Bank", "principal": 100000,
            "currency": "USD", "status": "active",
        })

        r = self.c.get("/api/portfolio")
        data = r.json()
        assert data["nav"] == -100000
        assert data["liabilities"] == 100000


# ---------------------------------------------------------------------------
# CRUD tests for all new API endpoints
# ---------------------------------------------------------------------------


class TestCapTableCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_cap_table_crud(self):
        # Create
        r = _post(self.c, "/api/cap-table", {
            "company_id": self.company_id,
            "round_name": "Series A",
            "investor": "Investor Corp",
            "instrument_type": "preferred",
            "shares": 10000,
            "amount_invested": 1000000,
            "currency": "USD",
            "date": "2024-01-15",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/cap-table")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["round_name"] == "Series A"

        # Delete
        r = self.c.delete(f"/api/cap-table/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/cap-table")
        assert not any(e["id"] == entry_id for e in r.json())


class TestShareholderResolutionCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_shareholder_resolution_crud(self):
        # Create
        r = _post(self.c, "/api/shareholder-resolutions", {
            "company_id": self.company_id,
            "title": "Approve Stock Split",
            "resolution_type": "ordinary",
            "date": "2024-03-15",
            "passed": True,
            "votes_for": 10,
            "votes_against": 2,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/shareholder-resolutions")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["title"] == "Approve Stock Split"
        assert found[0]["passed"] is True

        # Delete
        r = self.c.delete(f"/api/shareholder-resolutions/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/shareholder-resolutions")
        assert not any(e["id"] == entry_id for e in r.json())


class TestPowerOfAttorneyCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_power_of_attorney_crud(self):
        # Create
        r = _post(self.c, "/api/powers-of-attorney", {
            "company_id": self.company_id,
            "grantor": "John Smith",
            "grantee": "Jane Doe",
            "scope": "Full financial authority",
            "status": "active",
            "start_date": "2024-01-01",
            "end_date": "2025-12-31",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/powers-of-attorney")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["grantor"] == "John Smith"

        # Delete
        r = self.c.delete(f"/api/powers-of-attorney/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/powers-of-attorney")
        assert not any(e["id"] == entry_id for e in r.json())


class TestAnnualFilingCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_annual_filing_crud(self):
        # Create
        r = _post(self.c, "/api/annual-filings", {
            "company_id": self.company_id,
            "filing_type": "Annual Return",
            "jurisdiction": "US",
            "filing_date": "2024-03-01",
            "due_date": "2024-04-15",
            "status": "filed",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/annual-filings")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["filing_type"] == "Annual Return"

        # Delete
        r = self.c.delete(f"/api/annual-filings/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/annual-filings")
        assert not any(e["id"] == entry_id for e in r.json())


class TestBeneficialOwnerCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_beneficial_owner_crud(self):
        # Create
        r = _post(self.c, "/api/beneficial-owners", {
            "company_id": self.company_id,
            "name": "Alice Johnson",
            "nationality": "US",
            "ownership_pct": 25.5,
            "control_type": "direct",
            "verified": True,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/beneficial-owners")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "Alice Johnson"
        assert found[0]["ownership_pct"] == 25.5

        # Delete
        r = self.c.delete(f"/api/beneficial-owners/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/beneficial-owners")
        assert not any(e["id"] == entry_id for e in r.json())


class TestOwnershipChangeCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_ownership_change_crud(self):
        # Create
        r = _post(self.c, "/api/ownership-changes", {
            "company_id": self.company_id,
            "from_owner": "Old Corp",
            "to_owner": "New Corp",
            "ownership_pct": 51.0,
            "transaction_type": "acquisition",
            "date": "2024-06-01",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/ownership-changes")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["from_owner"] == "Old Corp"
        assert found[0]["ownership_pct"] == 51.0

        # Delete
        r = self.c.delete(f"/api/ownership-changes/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/ownership-changes")
        assert not any(e["id"] == entry_id for e in r.json())


class TestKeyPersonnelCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_key_personnel_crud(self):
        # Create
        r = _post(self.c, "/api/key-personnel", {
            "company_id": self.company_id,
            "name": "Bob Smith",
            "title": "CEO",
            "department": "Executive",
            "email": "bob@example.com",
            "phone": "+1-555-0100",
            "start_date": "2024-01-01",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/key-personnel")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "Bob Smith"
        assert found[0]["title"] == "CEO"

        # Delete
        r = self.c.delete(f"/api/key-personnel/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/key-personnel")
        assert not any(e["id"] == entry_id for e in r.json())


class TestRegulatoryLicenseCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_regulatory_license_crud(self):
        # Create
        r = _post(self.c, "/api/regulatory-licenses", {
            "company_id": self.company_id,
            "license_type": "Banking License",
            "issuing_authority": "Federal Reserve",
            "license_number": "BL-2024-001",
            "status": "active",
            "issue_date": "2024-01-01",
            "expiry_date": "2026-12-31",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/regulatory-licenses")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["license_type"] == "Banking License"

        # Delete
        r = self.c.delete(f"/api/regulatory-licenses/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/regulatory-licenses")
        assert not any(e["id"] == entry_id for e in r.json())


class TestJointVentureCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_joint_venture_crud(self):
        # Create
        r = _post(self.c, "/api/joint-ventures", {
            "company_id": self.company_id,
            "name": "JV Alpha",
            "partner": "Partner Corp",
            "ownership_pct": 50.0,
            "status": "active",
            "total_value": 1000000,
            "currency": "USD",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/joint-ventures")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "JV Alpha"
        assert found[0]["ownership_pct"] == 50.0

        # Delete
        r = self.c.delete(f"/api/joint-ventures/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/joint-ventures")
        assert not any(e["id"] == entry_id for e in r.json())


class TestEquityPlanCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_equity_plan_crud(self):
        # Create
        r = _post(self.c, "/api/equity-plans", {
            "company_id": self.company_id,
            "plan_name": "2024 Stock Option Plan",
            "total_pool": 100000,
            "vesting_schedule": "4yr/1yr cliff",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/equity-plans")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["plan_name"] == "2024 Stock Option Plan"
        assert found[0]["total_pool"] == 100000

        # Delete
        r = self.c.delete(f"/api/equity-plans/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/equity-plans")
        assert not any(e["id"] == entry_id for e in r.json())


class TestEquityGrantCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        # Create equity plan first
        r = _post(self.c, "/api/equity-plans", {
            "company_id": self.company_id,
            "plan_name": "2024 Plan",
            "total_pool": 100000,
        })
        self.plan_id = r.json()["id"]

    def test_equity_grant_crud(self):
        # Create
        r = _post(self.c, "/api/equity-grants", {
            "plan_id": self.plan_id,
            "recipient": "Alice Engineer",
            "grant_type": "options",
            "quantity": 1000,
            "strike_price": 10.0,
            "grant_date": "2024-06-01",
            "vesting_start": "2024-06-01",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/equity-grants")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["recipient"] == "Alice Engineer"
        assert found[0]["quantity"] == 1000

        # Delete
        r = self.c.delete(f"/api/equity-grants/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/equity-grants")
        assert not any(e["id"] == entry_id for e in r.json())


class TestDealCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_deal_crud(self):
        # Create
        r = _post(self.c, "/api/deals", {
            "company_id": self.company_id,
            "deal_type": "acquisition",
            "counterparty": "Target Inc",
            "status": "due_diligence",
            "value": 5000000,
            "currency": "USD",
            "target_close_date": "2024-12-31",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/deals")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["counterparty"] == "Target Inc"
        assert found[0]["value"] == 5000000

        # Delete
        r = self.c.delete(f"/api/deals/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/deals")
        assert not any(e["id"] == entry_id for e in r.json())


class TestAccountCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_account_crud(self):
        # Create
        r = _post(self.c, "/api/accounts", {
            "code": "1000",
            "name": "Cash",
            "account_type": "asset",
            "currency": "USD",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/accounts")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "Cash"
        assert found[0]["code"] == "1000"

        # Delete
        r = self.c.delete(f"/api/accounts/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/accounts")
        assert not any(e["id"] == entry_id for e in r.json())


class TestJournalEntryCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_journal_entry_crud(self):
        # Create
        r = _post(self.c, "/api/journal-entries", {
            "date": "2024-01-15",
            "description": "Opening balance",
            "reference": "JE-001",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/journal-entries")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["description"] == "Opening balance"
        assert found[0]["reference"] == "JE-001"

        # Delete
        r = self.c.delete(f"/api/journal-entries/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/journal-entries")
        assert not any(e["id"] == entry_id for e in r.json())


class TestJournalLineCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        # Create journal entry
        r = _post(self.c, "/api/journal-entries", {
            "date": "2024-01-15",
            "description": "Opening balance",
            "reference": "JE-001",
        })
        self.entry_id = r.json()["id"]
        # Create account
        r = _post(self.c, "/api/accounts", {
            "code": "1000",
            "name": "Cash",
            "account_type": "asset",
            "currency": "USD",
        })
        self.account_id = r.json()["id"]

    def test_journal_line_crud(self):
        # Create
        r = _post(self.c, "/api/journal-lines", {
            "entry_id": self.entry_id,
            "account_id": self.account_id,
            "debit": 1000,
            "credit": 0,
        })
        assert r.status_code == 201
        line_id = r.json()["id"]

        # List
        r = self.c.get("/api/journal-lines")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == line_id]
        assert len(found) == 1
        assert found[0]["debit"] == 1000
        assert found[0]["credit"] == 0

        # Delete
        r = self.c.delete(f"/api/journal-lines/{line_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/journal-lines")
        assert not any(e["id"] == line_id for e in r.json())


class TestInterCompanyTransferCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "Company A", "country": "US", "category": "T"})
        self.company_a_id = r.json()["id"]
        r = _post(self.c, "/api/companies", {"name": "Company B", "country": "UK", "category": "T"})
        self.company_b_id = r.json()["id"]

    def test_intercompany_transfer_crud(self):
        # Create
        r = _post(self.c, "/api/intercompany-transfers", {
            "from_company_id": self.company_a_id,
            "to_company_id": self.company_b_id,
            "amount": 50000,
            "currency": "USD",
            "date": "2024-06-15",
            "status": "completed",
            "description": "Operational funding",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/intercompany-transfers")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["amount"] == 50000

        # Delete
        r = self.c.delete(f"/api/intercompany-transfers/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/intercompany-transfers")
        assert not any(e["id"] == entry_id for e in r.json())


class TestDividendCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_dividend_crud(self):
        # Create
        r = _post(self.c, "/api/dividends", {
            "company_id": self.company_id,
            "dividend_type": "regular",
            "amount": 10000,
            "currency": "USD",
            "date": "2024-03-31",
            "recipient": "Shareholders",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/dividends")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["amount"] == 10000
        assert found[0]["dividend_type"] == "regular"

        # Delete
        r = self.c.delete(f"/api/dividends/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/dividends")
        assert not any(e["id"] == entry_id for e in r.json())


class TestCapitalContributionCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_capital_contribution_crud(self):
        # Create
        r = _post(self.c, "/api/capital-contributions", {
            "company_id": self.company_id,
            "contributor": "Founder",
            "amount": 100000,
            "currency": "USD",
            "date": "2024-01-01",
            "contribution_type": "cash",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/capital-contributions")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["contributor"] == "Founder"
        assert found[0]["amount"] == 100000

        # Delete
        r = self.c.delete(f"/api/capital-contributions/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/capital-contributions")
        assert not any(e["id"] == entry_id for e in r.json())


class TestTaxPaymentCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_tax_payment_crud(self):
        # Create
        r = _post(self.c, "/api/tax-payments", {
            "company_id": self.company_id,
            "tax_type": "corporate_income",
            "jurisdiction": "US",
            "amount": 25000,
            "currency": "USD",
            "date": "2024-04-15",
            "status": "paid",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/tax-payments")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["tax_type"] == "corporate_income"
        assert found[0]["amount"] == 25000

        # Delete
        r = self.c.delete(f"/api/tax-payments/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/tax-payments")
        assert not any(e["id"] == entry_id for e in r.json())


class TestBudgetCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_budget_crud(self):
        # Create
        r = _post(self.c, "/api/budgets", {
            "company_id": self.company_id,
            "period": "2024-Q1",
            "category": "operations",
            "budgeted": 100000,
            "actual": 95000,
            "currency": "USD",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/budgets")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["period"] == "2024-Q1"
        assert found[0]["budgeted"] == 100000

        # Delete
        r = self.c.delete(f"/api/budgets/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/budgets")
        assert not any(e["id"] == entry_id for e in r.json())


class TestCostBasisLotCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        # Create a holding
        r = _post(self.c, "/api/holdings", {
            "company_id": self.company_id,
            "asset": "AAPL",
            "ticker": "AAPL",
            "quantity": 100,
            "currency": "USD",
            "asset_type": "equity",
        })
        self.holding_id = r.json()["id"]

    def test_cost_basis_lot_crud(self):
        # Create
        r = _post(self.c, "/api/cost-basis-lots", {
            "holding_id": self.holding_id,
            "purchase_date": "2024-01-10",
            "quantity": 100,
            "price_per_unit": 50.0,
            "fees": 9.99,
            "currency": "USD",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/cost-basis-lots")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["quantity"] == 100
        assert found[0]["price_per_unit"] == 50.0

        # Delete
        r = self.c.delete(f"/api/cost-basis-lots/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/cost-basis-lots")
        assert not any(e["id"] == entry_id for e in r.json())


class TestRealEstatePropertyCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_real_estate_property_crud(self):
        # Create
        r = _post(self.c, "/api/real-estate", {
            "company_id": self.company_id,
            "name": "HQ Building",
            "property_type": "commercial",
            "address": "123 Main St",
            "purchase_price": 2000000,
            "current_valuation": 2500000,
            "currency": "USD",
            "purchase_date": "2020-06-01",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/real-estate")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "HQ Building"
        assert found[0]["purchase_price"] == 2000000

        # Delete
        r = self.c.delete(f"/api/real-estate/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/real-estate")
        assert not any(e["id"] == entry_id for e in r.json())


class TestFundInvestmentCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_fund_investment_crud(self):
        # Create
        r = _post(self.c, "/api/fund-investments", {
            "company_id": self.company_id,
            "fund_name": "VC Fund I",
            "fund_type": "venture_capital",
            "commitment": 500000,
            "called": 200000,
            "distributed": 50000,
            "nav": 180000,
            "currency": "USD",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/fund-investments")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["fund_name"] == "VC Fund I"
        assert found[0]["commitment"] == 500000

        # Delete
        r = self.c.delete(f"/api/fund-investments/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/fund-investments")
        assert not any(e["id"] == entry_id for e in r.json())


class TestCryptoWalletCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        # Create a holding
        r = _post(self.c, "/api/holdings", {
            "company_id": self.company_id,
            "asset": "Ethereum",
            "ticker": "ETH",
            "quantity": 50,
            "currency": "USD",
            "asset_type": "crypto",
        })
        self.holding_id = r.json()["id"]

    def test_crypto_wallet_crud(self):
        # Create
        r = _post(self.c, "/api/crypto-wallets", {
            "holding_id": self.holding_id,
            "blockchain": "ethereum",
            "wallet_type": "cold",
            "wallet_address": "0x1234567890abcdef",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/crypto-wallets")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["blockchain"] == "ethereum"
        assert found[0]["wallet_address"] == "0x1234567890abcdef"

        # Delete
        r = self.c.delete(f"/api/crypto-wallets/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/crypto-wallets")
        assert not any(e["id"] == entry_id for e in r.json())


class TestTransferPricingCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "Company A", "country": "US", "category": "T"})
        self.company_a_id = r.json()["id"]
        r = _post(self.c, "/api/companies", {"name": "Company B", "country": "UK", "category": "T"})
        self.company_b_id = r.json()["id"]

    def test_transfer_pricing_crud(self):
        # Create
        r = _post(self.c, "/api/transfer-pricing", {
            "from_company_id": self.company_a_id,
            "to_company_id": self.company_b_id,
            "description": "Management fees",
            "method": "comparable",
            "amount": 100000,
            "currency": "USD",
            "period": "2024",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/transfer-pricing")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["description"] == "Management fees"
        assert found[0]["amount"] == 100000

        # Delete
        r = self.c.delete(f"/api/transfer-pricing/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/transfer-pricing")
        assert not any(e["id"] == entry_id for e in r.json())


class TestWithholdingTaxCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_withholding_tax_crud(self):
        # Create
        r = _post(self.c, "/api/withholding-taxes", {
            "company_id": self.company_id,
            "payment_type": "dividend",
            "country_from": "US",
            "country_to": "UK",
            "gross_amount": 10000,
            "rate": 15.0,
            "tax_amount": 1500,
            "currency": "USD",
            "date": "2024-06-30",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/withholding-taxes")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["payment_type"] == "dividend"
        assert found[0]["tax_amount"] == 1500

        # Delete
        r = self.c.delete(f"/api/withholding-taxes/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/withholding-taxes")
        assert not any(e["id"] == entry_id for e in r.json())


class TestFatcaReportCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_fatca_report_crud(self):
        # Create
        r = _post(self.c, "/api/fatca-reports", {
            "company_id": self.company_id,
            "report_type": "fatca",
            "reporting_year": 2024,
            "jurisdiction": "US",
            "status": "filed",
            "filed_date": "2024-03-31",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/fatca-reports")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["reporting_year"] == 2024
        assert found[0]["status"] == "filed"

        # Delete
        r = self.c.delete(f"/api/fatca-reports/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/fatca-reports")
        assert not any(e["id"] == entry_id for e in r.json())


class TestESGScoreCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_esg_score_crud(self):
        # Create
        r = _post(self.c, "/api/esg-scores", {
            "company_id": self.company_id,
            "period": "2024",
            "environmental_score": 75.0,
            "social_score": 80.0,
            "governance_score": 85.0,
            "framework": "GRI",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/esg-scores")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["environmental_score"] == 75.0
        assert found[0]["framework"] == "GRI"

        # Delete
        r = self.c.delete(f"/api/esg-scores/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/esg-scores")
        assert not any(e["id"] == entry_id for e in r.json())


class TestRegulatoryFilingCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_regulatory_filing_crud(self):
        # Create
        r = _post(self.c, "/api/regulatory-filings", {
            "company_id": self.company_id,
            "filing_type": "10-K",
            "jurisdiction": "US",
            "due_date": "2024-03-31",
            "filed_date": "2024-03-15",
            "status": "filed",
            "reference_number": "RF-2024-001",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/regulatory-filings")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["filing_type"] == "10-K"
        assert found[0]["reference_number"] == "RF-2024-001"

        # Delete
        r = self.c.delete(f"/api/regulatory-filings/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/regulatory-filings")
        assert not any(e["id"] == entry_id for e in r.json())


class TestComplianceChecklistCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_compliance_checklist_crud(self):
        # Create
        r = _post(self.c, "/api/compliance-checklists", {
            "company_id": self.company_id,
            "item": "File annual return",
            "jurisdiction": "US",
            "category": "compliance",
            "completed": False,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/compliance-checklists")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["item"] == "File annual return"
        assert found[0]["completed"] is False

        # Delete
        r = self.c.delete(f"/api/compliance-checklists/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/compliance-checklists")
        assert not any(e["id"] == entry_id for e in r.json())


class TestDocumentVersionCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        # Create a document first
        r = _post(self.c, "/api/documents", {
            "company_id": self.company_id,
            "name": "Articles of Incorporation",
            "doc_type": "legal",
            "url": "https://docs.example.com/articles",
        })
        self.document_id = r.json()["id"]

    def test_document_version_crud(self):
        # Create
        r = _post(self.c, "/api/document-versions", {
            "document_id": self.document_id,
            "version_number": 2,
            "uploaded_by": "admin",
            "notes": "Updated version",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/document-versions")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["version_number"] == 2
        assert found[0]["uploaded_by"] == "admin"

        # Delete
        r = self.c.delete(f"/api/document-versions/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/document-versions")
        assert not any(e["id"] == entry_id for e in r.json())


class TestWebhookCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_webhook_crud(self):
        # Create
        r = _post(self.c, "/api/webhooks", {
            "url": "https://example.com/hook",
            "events": ["create", "update"],
            "is_active": True,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/webhooks")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["url"] == "https://example.com/hook"
        assert found[0]["events"] == ["create", "update"]

        # Delete
        r = self.c.delete(f"/api/webhooks/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/webhooks")
        assert not any(e["id"] == entry_id for e in r.json())


class TestApprovalRequestCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_approval_request_crud(self):
        # Create
        r = _post(self.c, "/api/approval-requests", {
            "action": "delete",
            "table_name": "company",
            "record_id": 1,
            "requested_by": "user1",
            "status": "pending",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/approval-requests")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["action"] == "delete"
        assert found[0]["status"] == "pending"

        # Delete
        r = self.c.delete(f"/api/approval-requests/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/approval-requests")
        assert not any(e["id"] == entry_id for e in r.json())


class TestCustomFieldCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_custom_field_crud(self):
        # Create
        r = _post(self.c, "/api/custom-fields", {
            "name": "Department",
            "field_type": "text",
            "entity_type": "company",
            "required": False,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/custom-fields")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "Department"
        assert found[0]["field_type"] == "text"

        # Delete
        r = self.c.delete(f"/api/custom-fields/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/custom-fields")
        assert not any(e["id"] == entry_id for e in r.json())


class TestCustomFieldValueCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        # Create custom field first
        r = _post(self.c, "/api/custom-fields", {
            "name": "Department",
            "field_type": "text",
            "entity_type": "company",
            "required": False,
        })
        self.custom_field_id = r.json()["id"]

    def test_custom_field_value_crud(self):
        # Create
        r = _post(self.c, "/api/custom-field-values", {
            "custom_field": self.custom_field_id,
            "entity_type": "company",
            "entity_id": 1,
            "value": "Engineering",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/custom-field-values")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["value"] == "Engineering"

        # Delete
        r = self.c.delete(f"/api/custom-field-values/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/custom-field-values")
        assert not any(e["id"] == entry_id for e in r.json())


class TestAPIKeyCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client, db):
        self.c = admin_client
        # Get the admin user id
        User = get_user_model()
        self.user = User.objects.get(username="adminuser")

    def test_api_key_crud(self):
        # Create
        r = _post(self.c, "/api/api-keys", {
            "name": "My API Key",
            "key": "test-key-123",
            "is_active": True,
            "user": self.user.id,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/api-keys")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "My API Key"

        # Delete
        r = self.c.delete(f"/api/api-keys/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/api-keys")
        assert not any(e["id"] == entry_id for e in r.json())


class TestEntityPermissionCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client, db):
        self.c = admin_client
        User = get_user_model()
        self.user = User.objects.get(username="adminuser")
        r = _post(self.c, "/api/companies", {"name": "TestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_entity_permission_crud(self):
        # Create
        r = _post(self.c, "/api/entity-permissions", {
            "user": self.user.id,
            "company": self.company_id,
            "permission_level": "view",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/entity-permissions")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["permission_level"] == "view"

        # Delete
        r = self.c.delete(f"/api/entity-permissions/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/entity-permissions")
        assert not any(e["id"] == entry_id for e in r.json())


class TestBackupConfigCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_backup_config_crud(self):
        # Create
        r = _post(self.c, "/api/backup-configs", {
            "name": "Daily Backup",
            "destination_type": "local",
            "destination_path": "./backups",
            "schedule": "daily",
            "retention_days": 30,
            "is_active": True,
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/backup-configs")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["name"] == "Daily Backup"
        assert found[0]["retention_days"] == 30

        # Delete
        r = self.c.delete(f"/api/backup-configs/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/backup-configs")
        assert not any(e["id"] == entry_id for e in r.json())


class TestBackupLogCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        # Create backup config first
        r = _post(self.c, "/api/backup-configs", {
            "name": "Daily Backup",
            "destination_type": "local",
            "destination_path": "./backups",
            "schedule": "daily",
            "retention_days": 30,
            "is_active": True,
        })
        self.config_id = r.json()["id"]

    def test_backup_log_crud(self):
        # Create
        r = _post(self.c, "/api/backup-logs", {
            "config_id": self.config_id,
            "status": "completed",
        })
        assert r.status_code == 201
        entry_id = r.json()["id"]

        # List
        r = self.c.get("/api/backup-logs")
        assert r.status_code == 200
        found = [e for e in r.json() if e["id"] == entry_id]
        assert len(found) == 1
        assert found[0]["status"] == "completed"

        # Delete
        r = self.c.delete(f"/api/backup-logs/{entry_id}")
        assert r.status_code == 200

        # Verify deleted
        r = self.c.get("/api/backup-logs")
        assert not any(e["id"] == entry_id for e in r.json())


# ---------------------------------------------------------------------------
# Computed endpoint tests
# ---------------------------------------------------------------------------


class TestSearchEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_search_returns_results(self):
        """Create a company, search for it by name."""
        r = _post(self.c, "/api/companies", {"name": "Acme Corp", "country": "US", "category": "T"})
        assert r.status_code == 201

        r = self.c.get("/api/search?q=Acme")
        assert r.status_code == 200
        data = r.json()
        assert data["count"] >= 1
        names = [res["name"] for res in data["results"]]
        assert "Acme Corp" in names

    def test_search_empty_query(self):
        """Search with empty q returns empty results."""
        r = self.c.get("/api/search?q=")
        assert r.status_code == 200
        data = r.json()
        assert data["results"] == []

    def test_search_no_match(self):
        """Search for gibberish returns empty results."""
        r = self.c.get("/api/search?q=zzzzxyznonexistent999")
        assert r.status_code == 200
        data = r.json()
        assert data["count"] == 0
        assert data["results"] == []


class TestCSVExport:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_csv_companies(self):
        """Create company, export CSV, verify content type and company name."""
        _post(self.c, "/api/companies", {"name": "CSV Test Co", "country": "US", "category": "T"})

        r = self.c.get("/api/export/csv?table=companies")
        assert r.status_code == 200
        assert "text/csv" in r["Content-Type"]
        content = r.content.decode("utf-8")
        assert "CSV Test Co" in content

    def test_csv_holdings(self):
        """Create holding, verify CSV export."""
        r = _post(self.c, "/api/companies", {"name": "HoldCo", "country": "US", "category": "T"})
        cid = r.json()["id"]
        _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "Gold Bars", "ticker": "GLD",
            "quantity": 100, "currency": "USD", "asset_type": "commodity",
        })

        r = self.c.get("/api/export/csv?table=holdings")
        assert r.status_code == 200
        assert "text/csv" in r["Content-Type"]
        content = r.content.decode("utf-8")
        assert "Gold Bars" in content


class TestGainsEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_gains_empty(self):
        """No holdings -> empty positions."""
        r = self.c.get("/api/gains")
        assert r.status_code == 200
        data = r.json()
        assert "positions" in data
        assert "total_unrealized" in data
        assert "total_realized" in data

    def test_gains_with_lots(self):
        """Create holding + cost basis lot, verify response structure."""
        r = _post(self.c, "/api/companies", {"name": "GainsCo", "country": "US", "category": "T"})
        cid = r.json()["id"]
        r = _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "AAPL Stock", "ticker": "AAPL",
            "quantity": 100, "currency": "USD", "asset_type": "equity",
        })
        hid = r.json()["id"]
        _post(self.c, "/api/cost-basis-lots", {
            "holding_id": hid, "purchase_date": "2024-01-10",
            "quantity": 100, "price_per_unit": 150.0, "fees": 0, "currency": "USD",
        })

        r = self.c.get("/api/gains")
        assert r.status_code == 200
        data = r.json()
        assert "positions" in data
        assert "total_unrealized" in data


class TestAssetAllocationEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_allocation_breakdown(self):
        """Create holdings with different asset_types, verify response."""
        r = _post(self.c, "/api/companies", {"name": "AllocCo", "country": "US", "category": "T"})
        cid = r.json()["id"]

        _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "Stocks", "quantity": 1000,
            "currency": "USD", "asset_type": "equity",
        })
        _post(self.c, "/api/holdings", {
            "company_id": cid, "asset": "BTC", "quantity": 5,
            "currency": "USD", "asset_type": "crypto",
        })

        r = self.c.get("/api/asset-allocation")
        assert r.status_code == 200
        data = r.json()
        assert "by_asset_type" in data
        assert "equity" in data["by_asset_type"]
        assert "crypto" in data["by_asset_type"]
        assert data["total_holdings"] == 2


class TestFXExposureEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_fx_exposure(self):
        """Create bank accounts in different currencies, verify."""
        r = _post(self.c, "/api/companies", {"name": "FXCo", "country": "US", "category": "T"})
        cid = r.json()["id"]

        _post(self.c, "/api/bank-accounts", {
            "company_id": cid, "bank_name": "Chase", "currency": "USD", "balance": 100000,
        })
        _post(self.c, "/api/bank-accounts", {
            "company_id": cid, "bank_name": "HSBC", "currency": "GBP", "balance": 50000,
        })

        r = self.c.get("/api/fx-exposure")
        assert r.status_code == 200
        data = r.json()
        assert "USD" in data
        assert "GBP" in data
        assert data["USD"]["assets"] == 100000
        assert data["GBP"]["assets"] == 50000


class TestCashFlowEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_cash_flow(self):
        """Create transactions, verify inflows/outflows."""
        r = _post(self.c, "/api/companies", {"name": "CashCo", "country": "US", "category": "T"})
        cid = r.json()["id"]

        _post(self.c, "/api/transactions", {
            "company_id": cid, "transaction_type": "deposit",
            "description": "Client payment", "amount": 50000,
            "date": "2024-01-15", "currency": "USD",
        })
        _post(self.c, "/api/transactions", {
            "company_id": cid, "transaction_type": "withdrawal",
            "description": "Rent", "amount": -10000,
            "date": "2024-01-20", "currency": "USD",
        })

        r = self.c.get("/api/cash-flow")
        assert r.status_code == 200
        data = r.json()
        assert data["inflows"] == 50000
        assert data["outflows"] == -10000
        assert data["net"] == 40000


class TestConsolidatedEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_consolidated_financials(self):
        """Create financials for multiple companies, verify aggregation."""
        r = _post(self.c, "/api/companies", {"name": "Sub A", "country": "US", "category": "T"})
        cid_a = r.json()["id"]
        r = _post(self.c, "/api/companies", {"name": "Sub B", "country": "UK", "category": "T"})
        cid_b = r.json()["id"]

        _post(self.c, "/api/financials", {
            "company_id": cid_a, "period": "2024-Q4",
            "revenue": 500000, "expenses": 300000, "currency": "USD",
        })
        _post(self.c, "/api/financials", {
            "company_id": cid_b, "period": "2024-Q4",
            "revenue": 200000, "expenses": 100000, "currency": "USD",
        })

        r = self.c.get("/api/consolidated")
        assert r.status_code == 200
        data = r.json()
        assert "2024-Q4" in data
        q4 = data["2024-Q4"]
        assert q4["revenue"] == 700000
        assert q4["expenses"] == 400000
        assert q4["net"] == 300000
        assert len(q4["companies"]) == 2


class TestContractAlertsEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_contract_alerts(self):
        """Create insurance with upcoming expiry, verify it shows."""
        from datetime import datetime, timedelta
        r = _post(self.c, "/api/companies", {"name": "AlertCo", "country": "US", "category": "T"})
        cid = r.json()["id"]

        # Set expiry to 30 days from now (within default 90-day window)
        expiry = (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%d")
        _post(self.c, "/api/insurance-policies", {
            "company_id": cid, "policy_type": "D&O",
            "provider": "AIG", "expiry_date": expiry,
        })

        r = self.c.get("/api/contract-alerts")
        assert r.status_code == 200
        data = r.json()
        assert data["count"] >= 1
        assert any(a["type"] == "insurance" for a in data["alerts"])


class TestOwnershipDiagramEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_ownership_diagram(self):
        """Create parent + subsidiary, verify mermaid output."""
        r = _post(self.c, "/api/companies", {
            "name": "Parent Corp", "country": "US", "category": "Holding", "is_holding": True,
        })
        parent_id = r.json()["id"]
        _post(self.c, "/api/companies", {
            "name": "Child Inc", "country": "US", "category": "Tech",
            "parent_id": parent_id, "ownership_pct": 100,
        })

        r = self.c.get("/api/ownership-diagram")
        assert r.status_code == 200
        data = r.json()
        assert "mermaid" in data
        mermaid = data["mermaid"]
        assert "graph TD" in mermaid
        assert "Parent Corp" in mermaid
        assert "Child Inc" in mermaid
        assert "owns" in mermaid


class TestBenchmarkEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_benchmarks(self):
        """Verify the endpoint returns 200 and has expected keys."""
        r = self.c.get("/api/benchmarks")
        assert r.status_code == 200
        data = r.json()
        # The endpoint returns benchmark tickers as top-level keys
        assert "SPY" in data
        assert "BTC-USD" in data
        assert "GLD" in data
        for key in ["SPY", "BTC-USD", "GLD"]:
            assert "name" in data[key]
            assert "price" in data[key]


class TestBulkUpdateEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_bulk_update_category(self):
        """Create companies, bulk update their category, verify."""
        ids = []
        for name in ["Bulk A", "Bulk B", "Bulk C"]:
            r = _post(self.c, "/api/companies", {"name": name, "country": "US", "category": "Old"})
            assert r.status_code == 201
            ids.append(r.json()["id"])

        # Bulk update category
        r = _post(self.c, "/api/bulk-update", {
            "ids": ids,
            "updates": {"category": "NewCat"},
        })
        assert r.status_code == 200
        assert r.json()["updated"] == 3

        # Verify
        r = self.c.get("/api/companies")
        for company in r.json():
            if company["id"] in ids:
                assert company["category"] == "NewCat"


# ---------------------------------------------------------------------------
# Wave 2: Multi-tenant, Treasury, Sanctions, etc.
# ---------------------------------------------------------------------------


class TestTenantGroupCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_tenant_group_crud(self):
        r = _post(self.c, "/api/tenant-groups", {"name": "Acme Group", "slug": "acme-group"})
        assert r.status_code == 201
        gid = r.json()["id"]
        r = self.c.get("/api/tenant-groups")
        assert any(g["id"] == gid for g in r.json())
        r = self.c.delete(f"/api/tenant-groups/{gid}")
        assert r.status_code == 200


class TestCashPoolCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_cash_pool_crud(self):
        r = _post(self.c, "/api/cash-pools", {"name": "USD Pool", "currency": "USD", "target_balance": 1000000})
        assert r.status_code == 201
        pid = r.json()["id"]
        r = self.c.get("/api/cash-pools")
        assert any(p["id"] == pid for p in r.json())
        r = self.c.delete(f"/api/cash-pools/{pid}")
        assert r.status_code == 200


class TestCashPoolEntryCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "PoolCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        r = _post(self.c, "/api/cash-pools", {"name": "Main Pool", "currency": "USD"})
        self.pool_id = r.json()["id"]

    def test_cash_pool_entry_crud(self):
        r = _post(self.c, "/api/cash-pool-entries", {
            "pool_id": self.pool_id, "company_id": self.company_id, "allocated_amount": 50000,
        })
        assert r.status_code == 201
        eid = r.json()["id"]
        r = self.c.get("/api/cash-pool-entries")
        assert any(e["id"] == eid for e in r.json())
        r = self.c.delete(f"/api/cash-pool-entries/{eid}")
        assert r.status_code == 200


class TestSanctionsListCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_sanctions_list_crud(self):
        r = _post(self.c, "/api/sanctions-lists", {"name": "OFAC SDN", "list_type": "ofac_sdn"})
        assert r.status_code == 201
        lid = r.json()["id"]
        r = self.c.get("/api/sanctions-lists")
        assert any(s["id"] == lid for s in r.json())
        r = self.c.delete(f"/api/sanctions-lists/{lid}")
        assert r.status_code == 200


class TestSanctionsEntryCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/sanctions-lists", {"name": "Test List", "list_type": "custom"})
        self.list_id = r.json()["id"]

    def test_sanctions_entry_crud(self):
        r = _post(self.c, "/api/sanctions-entries", {
            "sanctions_list_id": self.list_id, "name": "Bad Actor Corp", "entity_type": "entity", "country": "XX",
        })
        assert r.status_code == 201
        eid = r.json()["id"]
        r = self.c.get("/api/sanctions-entries")
        assert any(e["id"] == eid for e in r.json())
        r = self.c.delete(f"/api/sanctions-entries/{eid}")
        assert r.status_code == 200


class TestSanctionsCheckCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "CheckCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_sanctions_check_crud(self):
        r = _post(self.c, "/api/sanctions-checks", {
            "company_id": self.company_id, "checked_name": "CheckCo", "status": "clear",
        })
        assert r.status_code == 201
        cid = r.json()["id"]
        r = self.c.get("/api/sanctions-checks")
        assert any(c["id"] == cid for c in r.json())
        r = self.c.delete(f"/api/sanctions-checks/{cid}")
        assert r.status_code == 200


class TestPortfolioSnapshotCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_portfolio_snapshot_crud(self):
        r = _post(self.c, "/api/portfolio-snapshots", {
            "date": "2024-01-15", "liquid": 100000, "marketable": 200000,
            "illiquid": 50000, "liabilities": 30000, "nav": 320000, "currency": "USD",
        })
        assert r.status_code == 201
        sid = r.json()["id"]
        r = self.c.get("/api/portfolio-snapshots")
        assert any(s["id"] == sid for s in r.json())
        r = self.c.delete(f"/api/portfolio-snapshots/{sid}")
        assert r.status_code == 200


class TestAccountingSyncConfigCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "SyncCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_accounting_sync_config_crud(self):
        r = _post(self.c, "/api/accounting-sync-configs", {
            "company_id": self.company_id, "provider": "quickbooks", "is_active": True,
        })
        assert r.status_code == 201
        cid = r.json()["id"]
        r = self.c.get("/api/accounting-sync-configs")
        assert any(c["id"] == cid for c in r.json())
        r = self.c.delete(f"/api/accounting-sync-configs/{cid}")
        assert r.status_code == 200


class TestBankFeedConfigCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "FeedCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        r = _post(self.c, "/api/bank-accounts", {
            "company_id": self.company_id, "bank_name": "Test Bank", "currency": "USD", "balance": 10000,
        })
        self.account_id = r.json()["id"]

    def test_bank_feed_config_crud(self):
        r = _post(self.c, "/api/bank-feed-configs", {
            "company_id": self.company_id, "bank_account_id": self.account_id,
            "provider": "plaid", "is_active": True,
        })
        assert r.status_code == 201
        cid = r.json()["id"]
        r = self.c.get("/api/bank-feed-configs")
        assert any(c["id"] == cid for c in r.json())
        r = self.c.delete(f"/api/bank-feed-configs/{cid}")
        assert r.status_code == 200


class TestSignatureRequestCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "SignCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]
        r = _post(self.c, "/api/documents", {
            "company_id": self.company_id, "name": "Contract", "doc_type": "contract",
        })
        self.doc_id = r.json()["id"]

    def test_signature_request_crud(self):
        r = _post(self.c, "/api/signature-requests", {
            "company_id": self.company_id, "document_id": self.doc_id,
            "provider": "docusign", "status": "draft", "signers": "ceo@example.com",
        })
        assert r.status_code == 201
        rid = r.json()["id"]
        r = self.c.get("/api/signature-requests")
        assert any(s["id"] == rid for s in r.json())
        r = self.c.delete(f"/api/signature-requests/{rid}")
        assert r.status_code == 200


class TestInvestorAccessCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "InvestCo", "country": "US", "category": "T"})
        self.company_id = r.json()["id"]

    def test_investor_access_crud(self):
        from django.contrib.auth import get_user_model
        User = get_user_model()
        user = User.objects.first()
        r = _post(self.c, "/api/investor-access", {
            "company_id": self.company_id, "user": user.id,
            "can_view_financials": True, "can_view_holdings": True,
        })
        assert r.status_code == 201
        aid = r.json()["id"]
        r = self.c.get("/api/investor-access")
        assert any(a["id"] == aid for a in r.json())
        r = self.c.delete(f"/api/investor-access/{aid}")
        assert r.status_code == 200


class TestDocumentUploadCRUD:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client
        r = _post(self.c, "/api/companies", {"name": "UploadCo", "country": "US", "category": "T"})
        cid = r.json()["id"]
        r = _post(self.c, "/api/documents", {"company_id": cid, "name": "Report", "doc_type": "report"})
        self.doc_id = r.json()["id"]

    def test_document_upload_crud(self):
        r = _post(self.c, "/api/document-uploads", {
            "document_id": self.doc_id, "storage_backend": "local",
            "file_path": "/uploads/report.pdf", "file_name": "report.pdf",
            "file_size": 1024, "content_type": "application/pdf",
        })
        assert r.status_code == 201
        uid = r.json()["id"]
        r = self.c.get("/api/document-uploads")
        assert any(u["id"] == uid for u in r.json())
        r = self.c.delete(f"/api/document-uploads/{uid}")
        assert r.status_code == 200


# ---------------------------------------------------------------------------
# Wave 2: Computed Endpoints
# ---------------------------------------------------------------------------


class TestNLQEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_nlq_companies_in_country(self):
        _post(self.c, "/api/companies", {"name": "US Corp", "country": "US", "category": "T"})
        r = self.c.get("/api/nlq?q=companies+in+US")
        assert r.status_code == 200
        data = r.json()
        assert data["count"] >= 1
        assert "us" in data["interpretation"].lower()

    def test_nlq_empty_query(self):
        r = self.c.get("/api/nlq?q=")
        assert r.status_code == 200
        assert r.json()["results"] == []

    def test_nlq_portfolio(self):
        r = self.c.get("/api/nlq?q=total+nav")
        assert r.status_code == 200
        assert r.json()["count"] >= 1


class TestTaxLossHarvestingEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_tax_loss_harvesting_empty(self):
        r = self.c.get("/api/tax-loss-harvesting")
        assert r.status_code == 200
        data = r.json()
        assert "total_harvestable_loss" in data
        assert "suggestions" in data


class TestPnlTrendsEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_pnl_trends(self):
        r = _post(self.c, "/api/companies", {"name": "TrendCo", "country": "US", "category": "T"})
        cid = r.json()["id"]
        _post(self.c, "/api/financials", {
            "company_id": cid, "period": "2024-Q1", "revenue": 100000, "expenses": 80000, "currency": "USD",
        })
        r = self.c.get("/api/pnl-trends")
        assert r.status_code == 200
        data = r.json()
        assert "periods" in data
        assert "series" in data


class TestAssetAllocationChartEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_allocation_chart(self):
        r = self.c.get("/api/asset-allocation-chart")
        assert r.status_code == 200
        data = r.json()
        assert "slices" in data
        assert "total_holdings" in data


class TestBoardPackagePDF:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_board_package_pdf(self):
        r = _post(self.c, "/api/companies", {"name": "PDF Co", "country": "US", "category": "T"})
        cid = r.json()["id"]
        r = self.c.get(f"/api/board-package.pdf?company_id={cid}")
        assert r.status_code == 200
        assert r["Content-Type"] == "application/pdf"

    def test_board_package_requires_company(self):
        r = self.c.get("/api/board-package.pdf")
        assert r.status_code == 400


class TestICalExport:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_ical_export(self):
        r = self.c.get("/api/calendar.ics")
        assert r.status_code == 200
        assert "text/calendar" in r["Content-Type"]


class TestInvestorPortalEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_investor_portal_no_access(self):
        r = self.c.get("/api/investor-portal")
        assert r.status_code == 200
        data = r.json()
        assert "companies" in data


class TestPortfolioPerformanceEndpoint:
    @pytest.fixture(autouse=True)
    def setup(self, admin_client):
        self.c = admin_client

    def test_portfolio_performance_empty(self):
        r = self.c.get("/api/portfolio-performance")
        assert r.status_code == 200
        data = r.json()
        assert "dates" in data
        assert "nav" in data

    def test_portfolio_performance_with_data(self):
        _post(self.c, "/api/portfolio-snapshots", {
            "date": "2024-01-01", "liquid": 100000, "marketable": 200000,
            "illiquid": 50000, "liabilities": 30000, "nav": 320000, "currency": "USD",
        })
        _post(self.c, "/api/portfolio-snapshots", {
            "date": "2024-06-01", "liquid": 120000, "marketable": 250000,
            "illiquid": 55000, "liabilities": 25000, "nav": 400000, "currency": "USD",
        })
        r = self.c.get("/api/portfolio-performance?days=3650")
        assert r.status_code == 200
        data = r.json()
        assert len(data["dates"]) == 2
        assert data["return_pct"] > 0
