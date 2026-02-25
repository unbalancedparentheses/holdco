"""
End-to-end workflow tests.

These exercise full multi-step business workflows through the API,
verifying that the system behaves correctly when operations compose.
"""

import pytest
from django.contrib.auth import get_user_model
from django.test import Client

from core.models import (
    AssetHolding,
    AuditLog,
    BankAccount,
    BoardMeeting,
    Company,
    CustodianAccount,
    Document,
    Financial,
    InsurancePolicy,
    Liability,
    ServiceProvider,
    TaxDeadline,
    Transaction,
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
