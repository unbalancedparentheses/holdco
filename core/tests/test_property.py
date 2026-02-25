"""
Property-based tests using Hypothesis.

These generate random valid data and verify invariants hold across
all inputs — catching edge cases that hand-written tests miss.
"""

import pytest
from hypothesis import given, settings, assume, HealthCheck
from hypothesis import strategies as st
from django.contrib.auth import get_user_model
from django.test import Client

from core.models import (
    AssetHolding,
    BankAccount,
    BoardMeeting,
    Category,
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
    get_user_role,
)

JSON = "application/json"

# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

# Safe text: printable, no null bytes, reasonable length
safe_text = st.text(
    alphabet=st.characters(whitelist_categories=("L", "N", "P", "Z"), blacklist_characters="\x00"),
    min_size=1,
    max_size=200,
)

safe_name = st.text(
    alphabet=st.characters(whitelist_categories=("L", "N", "Z"), blacklist_characters="\x00"),
    min_size=1,
    max_size=200,
)

country_st = st.text(
    alphabet=st.characters(whitelist_categories=("L",), blacklist_characters="\x00"),
    min_size=1,
    max_size=100,
)

color_st = st.from_regex(r"#[0-9a-f]{6}", fullmatch=True)

positive_float = st.floats(min_value=0, max_value=1e12, allow_nan=False, allow_infinity=False)
any_float = st.floats(min_value=-1e12, max_value=1e12, allow_nan=False, allow_infinity=False)

date_st = st.from_regex(r"20[2-3][0-9]-[01][0-9]-[0-3][0-9]", fullmatch=True)
period_st = st.from_regex(r"20[2-3][0-9]-Q[1-4]", fullmatch=True)
currency_st = st.sampled_from(["USD", "EUR", "GBP", "CHF", "JPY", "BTC", "ETH"])

role_st = st.sampled_from(["admin", "editor", "viewer"])


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def admin(db):
    User = get_user_model()
    user = User.objects.create_user(username="prop_admin", password="pass")
    UserRole.objects.create(user=user, role="admin")
    client = Client()
    client.force_login(user)
    return client


@pytest.fixture
def company(admin):
    r = admin.post("/api/companies", {"name": "PropCo", "country": "US", "category": "T"}, content_type=JSON)
    return r.json()["id"]


# ---------------------------------------------------------------------------
# Model-level properties
# ---------------------------------------------------------------------------


class TestGetUserRoleProperty:
    @given(role=role_st)
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_role_always_in_valid_set(self, db, role):
        User = get_user_model()
        username = f"user_{role}_{id(role)}"
        user = User.objects.create_user(username=username, password="pass")
        UserRole.objects.create(user=user, role=role)
        assert get_user_role(user) in {"admin", "editor", "viewer"}

    @given(data=st.data())
    @settings(max_examples=10, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_no_role_always_viewer(self, db, data):
        User = get_user_model()
        username = f"norole_{data.draw(st.integers(min_value=0, max_value=999999))}"
        assume(not User.objects.filter(username=username).exists())
        user = User.objects.create_user(username=username, password="pass")
        assert get_user_role(user) == "viewer"


# ---------------------------------------------------------------------------
# Company round-trip properties
# ---------------------------------------------------------------------------


class TestCompanyProperties:
    @given(name=safe_name, country=country_st, category=safe_name)
    @settings(max_examples=30, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_create_roundtrip(self, admin, name, country, category):
        """Any valid company data round-trips through create → list."""
        r = admin.post("/api/companies", {
            "name": name, "country": country, "category": category,
        }, content_type=JSON)
        assert r.status_code == 201
        cid = r.json()["id"]

        r = admin.get("/api/companies")
        found = [c for c in r.json() if c["id"] == cid]
        assert len(found) == 1
        assert found[0]["name"] == name
        assert found[0]["country"] == country

        # Cleanup
        admin.delete(f"/api/companies/{cid}")

    @given(original=safe_name, updated=safe_name)
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_update_preserves_other_fields(self, admin, original, updated):
        """Updating name doesn't change country."""
        r = admin.post("/api/companies", {
            "name": original, "country": "FixedCountry", "category": "FixedCat",
        }, content_type=JSON)
        cid = r.json()["id"]

        admin.put(f"/api/companies/{cid}", {"name": updated}, content_type=JSON)

        r = admin.get("/api/companies")
        found = [c for c in r.json() if c["id"] == cid]
        assert found[0]["country"] == "FixedCountry"
        assert found[0]["name"] == updated

        admin.delete(f"/api/companies/{cid}")


# ---------------------------------------------------------------------------
# Category properties
# ---------------------------------------------------------------------------


class TestCategoryProperties:
    @given(name=safe_name, color=color_st)
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_create_roundtrip(self, admin, name, color):
        r = admin.post("/api/categories", {"name": name, "color": color}, content_type=JSON)
        # Unique constraint may reject duplicates — that's fine
        if r.status_code == 201:
            cid = r.json()["id"]
            r = admin.get("/api/categories")
            found = [c for c in r.json() if c["id"] == cid]
            assert len(found) == 1
            assert found[0]["color"] == color
            admin.delete(f"/api/categories/{cid}")


# ---------------------------------------------------------------------------
# AssetHolding properties
# ---------------------------------------------------------------------------


class TestHoldingProperties:
    @given(asset=safe_name, ticker=st.text(min_size=1, max_size=20), quantity=positive_float, currency=currency_st)
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_holding_roundtrip(self, admin, company, asset, ticker, quantity, currency):
        r = admin.post("/api/holdings", {
            "company_id": company, "asset": asset, "ticker": ticker,
            "quantity": quantity, "currency": currency,
        }, content_type=JSON)
        assert r.status_code == 201
        hid = r.json()["id"]

        r = admin.get("/api/holdings")
        found = [h for h in r.json() if h["id"] == hid]
        assert len(found) == 1
        assert found[0]["asset"] == asset

        admin.delete(f"/api/holdings/{hid}")


# ---------------------------------------------------------------------------
# Financial properties
# ---------------------------------------------------------------------------


class TestFinancialProperties:
    @given(period=period_st, revenue=any_float, expenses=any_float, currency=currency_st)
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_financial_roundtrip(self, admin, company, period, revenue, expenses, currency):
        r = admin.post("/api/financials", {
            "company_id": company, "period": period,
            "revenue": revenue, "expenses": expenses, "currency": currency,
        }, content_type=JSON)
        assert r.status_code == 201
        fid = r.json()["id"]

        r = admin.get("/api/financials")
        found = [f for f in r.json() if f["id"] == fid]
        assert len(found) == 1
        assert found[0]["period"] == period

        admin.delete(f"/api/financials/{fid}")


# ---------------------------------------------------------------------------
# Transaction properties
# ---------------------------------------------------------------------------


class TestTransactionProperties:
    @given(
        txn_type=st.sampled_from(["dividend", "deposit", "withdrawal", "transfer", "buy", "sell"]),
        description=safe_text,
        amount=any_float,
        date=date_st,
        currency=currency_st,
    )
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_transaction_roundtrip(self, admin, company, txn_type, description, amount, date, currency):
        r = admin.post("/api/transactions", {
            "company_id": company, "transaction_type": txn_type,
            "description": description, "amount": amount,
            "date": date, "currency": currency,
        }, content_type=JSON)
        assert r.status_code == 201
        tid = r.json()["id"]

        r = admin.get("/api/transactions")
        found = [t for t in r.json() if t["id"] == tid]
        assert len(found) == 1

        admin.delete(f"/api/transactions/{tid}")


# ---------------------------------------------------------------------------
# BankAccount properties
# ---------------------------------------------------------------------------


class TestBankAccountProperties:
    @given(
        bank_name=safe_name,
        balance=any_float,
        currency=currency_st,
        account_type=st.sampled_from(["operating", "savings", "escrow", "trust"]),
    )
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_bank_account_roundtrip(self, admin, company, bank_name, balance, currency, account_type):
        r = admin.post("/api/bank-accounts", {
            "company_id": company, "bank_name": bank_name,
            "balance": balance, "currency": currency, "account_type": account_type,
        }, content_type=JSON)
        assert r.status_code == 201
        aid = r.json()["id"]

        r = admin.get("/api/bank-accounts")
        found = [a for a in r.json() if a["id"] == aid]
        assert len(found) == 1
        assert found[0]["bank_name"] == bank_name

        admin.delete(f"/api/bank-accounts/{aid}")


# ---------------------------------------------------------------------------
# Liability properties
# ---------------------------------------------------------------------------


class TestLiabilityProperties:
    @given(
        creditor=safe_name,
        principal=positive_float,
        currency=currency_st,
        interest_rate=st.floats(min_value=0, max_value=100, allow_nan=False, allow_infinity=False),
    )
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_liability_roundtrip(self, admin, company, creditor, principal, currency, interest_rate):
        r = admin.post("/api/liabilities", {
            "company_id": company, "liability_type": "loan",
            "creditor": creditor, "principal": principal,
            "currency": currency, "interest_rate": interest_rate, "status": "active",
        }, content_type=JSON)
        assert r.status_code == 201
        lid = r.json()["id"]

        r = admin.get("/api/liabilities")
        found = [l for l in r.json() if l["id"] == lid]
        assert len(found) == 1

        admin.delete(f"/api/liabilities/{lid}")


# ---------------------------------------------------------------------------
# Stats invariants
# ---------------------------------------------------------------------------


class TestHoldingAssetTypeProperties:
    @given(
        asset=safe_name,
        asset_type=st.sampled_from(["equity", "crypto", "commodity", "real_estate", "private_equity", "other"]),
        quantity=positive_float,
        currency=currency_st,
    )
    @settings(max_examples=20, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_asset_type_roundtrip(self, admin, company, asset, asset_type, quantity, currency):
        r = admin.post("/api/holdings", {
            "company_id": company, "asset": asset,
            "quantity": quantity, "currency": currency,
            "asset_type": asset_type,
        }, content_type=JSON)
        assert r.status_code == 201
        hid = r.json()["id"]

        r = admin.get("/api/holdings")
        found = [h for h in r.json() if h["id"] == hid]
        assert len(found) == 1
        assert found[0]["asset_type"] == asset_type

        admin.delete(f"/api/holdings/{hid}")


class TestPortfolioInvariants:
    @given(
        n_accounts=st.integers(min_value=0, max_value=5),
        n_holdings=st.integers(min_value=0, max_value=5),
        n_liabilities=st.integers(min_value=0, max_value=5),
    )
    @settings(max_examples=10, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_nav_equals_assets_minus_liabilities(self, admin, n_accounts, n_holdings, n_liabilities):
        """NAV = liquid + marketable + illiquid - liabilities, always."""
        # Create company
        r = admin.post("/api/companies", {
            "name": "NavCo", "country": "US", "category": "T",
        }, content_type=JSON)
        cid = r.json()["id"]

        # Create bank accounts
        for i in range(n_accounts):
            admin.post("/api/bank-accounts", {
                "company_id": cid, "bank_name": f"Bank-{i}",
                "currency": "USD", "balance": 10000,
            }, content_type=JSON)

        # Create illiquid holdings (no ticker)
        for i in range(n_holdings):
            admin.post("/api/holdings", {
                "company_id": cid, "asset": f"Asset-{i}",
                "quantity": 5000, "currency": "USD",
                "asset_type": "real_estate",
            }, content_type=JSON)

        # Create active liabilities
        for i in range(n_liabilities):
            admin.post("/api/liabilities", {
                "company_id": cid, "liability_type": "loan",
                "creditor": f"Bank-{i}", "principal": 3000,
                "currency": "USD", "status": "active",
            }, content_type=JSON)

        r = admin.get("/api/portfolio")
        data = r.json()

        expected = data["liquid"] + data["marketable"] + data["illiquid"] - data["liabilities"]
        assert abs(data["nav"] - expected) < 0.01, f"NAV {data['nav']} != {expected}"

        # Cleanup
        admin.delete(f"/api/companies/{cid}")


class TestStatsInvariants:
    @given(n=st.integers(min_value=1, max_value=10))
    @settings(max_examples=5, suppress_health_check=[HealthCheck.too_slow, HealthCheck.function_scoped_fixture])
    def test_total_equals_top_plus_subs(self, admin, n):
        """total_companies == top_level_entities + subsidiaries, always."""
        ids = []
        parent_id = None
        for i in range(n):
            payload = {"name": f"S-{i}", "country": "US", "category": "T"}
            if i > 0 and parent_id:
                payload["parent_id"] = parent_id
            r = admin.post("/api/companies", payload, content_type=JSON)
            cid = r.json()["id"]
            ids.append(cid)
            if i == 0:
                parent_id = cid

        r = admin.get("/api/stats")
        stats = r.json()
        assert stats["total_companies"] == stats["top_level_entities"] + stats["subsidiaries"]

        # Cleanup
        for cid in reversed(ids):
            admin.delete(f"/api/companies/{cid}")
