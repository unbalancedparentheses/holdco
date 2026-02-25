"""
Fuzz / adversarial input tests.

These throw malformed, unexpected, and hostile data at every API endpoint
to verify the system handles it gracefully — returning 400/403/404
instead of 500, and never corrupting data.
"""

import pytest
from django.test import Client

JSON = "application/json"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


@pytest.fixture
def company_id(admin_client):
    r = admin_client.post(
        "/api/companies", {"name": "FuzzCo", "country": "US", "category": "T"},
        content_type=JSON,
    )
    return r.json()["id"]


@pytest.fixture
def holding_id(admin_client, company_id):
    r = admin_client.post(
        "/api/holdings", {"company_id": company_id, "asset": "Gold"},
        content_type=JSON,
    )
    return r.json()["id"]


def assert_no_500(response):
    """The server must never return 5xx for any input."""
    assert response.status_code < 500, (
        f"Got {response.status_code}: {response.content[:500]}"
    )


# ---------------------------------------------------------------------------
# Malformed JSON
# ---------------------------------------------------------------------------


class TestMalformedJSON:
    def test_invalid_json_body(self, admin_client):
        r = admin_client.post("/api/companies", "not json at all", content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_empty_body(self, admin_client):
        r = admin_client.post("/api/companies", "", content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_null_body(self, admin_client):
        r = admin_client.post("/api/companies", "null", content_type=JSON)
        assert_no_500(r)

    def test_array_instead_of_object(self, admin_client):
        r = admin_client.post("/api/companies", [1, 2, 3], content_type=JSON)
        assert_no_500(r)

    def test_nested_deep_json(self, admin_client):
        deep = {"a": {"b": {"c": {"d": {"e": "deep"}}}}}
        r = admin_client.post("/api/companies", deep, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Wrong types
# ---------------------------------------------------------------------------


class TestWrongTypes:
    def test_string_where_int_expected(self, admin_client, company_id):
        r = admin_client.post("/api/holdings", {
            "company_id": "not-a-number", "asset": "BTC",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_bool_for_string_field(self, admin_client):
        r = admin_client.post("/api/companies", {
            "name": True, "country": False, "category": 12345,
        }, content_type=JSON)
        assert_no_500(r)

    def test_float_for_integer_field(self, admin_client, company_id):
        r = admin_client.put(f"/api/companies/{company_id}", {
            "ownership_pct": 99.99,
        }, content_type=JSON)
        assert_no_500(r)

    def test_negative_quantity(self, admin_client, company_id):
        r = admin_client.post("/api/holdings", {
            "company_id": company_id, "asset": "X", "quantity": -999,
        }, content_type=JSON)
        assert_no_500(r)

    def test_nan_amount(self, admin_client, company_id):
        r = admin_client.post("/api/transactions", {
            "company_id": company_id, "transaction_type": "buy",
            "description": "x", "amount": "NaN", "date": "2025-01-01",
        }, content_type=JSON)
        assert_no_500(r)

    def test_infinity_balance(self, admin_client, company_id):
        r = admin_client.post("/api/bank-accounts", {
            "company_id": company_id, "bank_name": "Test",
            "balance": "Infinity",
        }, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# SQL injection attempts
# ---------------------------------------------------------------------------

SQL_INJECTIONS = [
    "'; DROP TABLE core_company; --",
    "1 OR 1=1",
    "' UNION SELECT * FROM auth_user --",
    "1; DELETE FROM core_company WHERE ''='",
    "Robert'); DROP TABLE core_company;--",
]


class TestSQLInjection:
    @pytest.mark.parametrize("payload", SQL_INJECTIONS)
    def test_sql_in_company_name(self, admin_client, payload):
        r = admin_client.post("/api/companies", {
            "name": payload, "country": "US", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)
        if r.status_code == 201:
            # The injection was stored as literal text, not executed
            r2 = admin_client.get("/api/companies")
            names = [c["name"] for c in r2.json()]
            assert payload in names

    @pytest.mark.parametrize("payload", SQL_INJECTIONS)
    def test_sql_in_settings_key(self, admin_client, payload):
        r = admin_client.put(f"/api/settings/{payload}", {"value": "x"}, content_type=JSON)
        assert_no_500(r)

    @pytest.mark.parametrize("payload", SQL_INJECTIONS)
    def test_sql_in_category_name(self, admin_client, payload):
        r = admin_client.post("/api/categories", {"name": payload}, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# XSS payloads
# ---------------------------------------------------------------------------

XSS_PAYLOADS = [
    "<script>alert('xss')</script>",
    '<img src=x onerror=alert(1)>',
    "javascript:alert(1)",
    '"><svg onload=alert(1)>',
    "{{7*7}}",  # Template injection
]


class TestXSSPayloads:
    @pytest.mark.parametrize("payload", XSS_PAYLOADS)
    def test_xss_in_company_name(self, admin_client, payload):
        r = admin_client.post("/api/companies", {
            "name": payload, "country": "US", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)
        if r.status_code == 201:
            # Stored as-is (no sanitization needed for JSON API, templates auto-escape)
            r2 = admin_client.get("/api/companies")
            names = [c["name"] for c in r2.json()]
            assert payload in names

    @pytest.mark.parametrize("payload", XSS_PAYLOADS)
    def test_xss_in_notes_field(self, admin_client, company_id, payload):
        r = admin_client.post("/api/documents", {
            "company_id": company_id, "name": "doc", "notes": payload,
        }, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Extremely long strings
# ---------------------------------------------------------------------------


class TestLongStrings:
    def test_very_long_name(self, admin_client):
        name = "A" * 10000
        r = admin_client.post("/api/companies", {
            "name": name, "country": "US", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)

    def test_very_long_notes(self, admin_client, company_id):
        notes = "x" * 100000
        r = admin_client.post("/api/documents", {
            "company_id": company_id, "name": "doc", "notes": notes,
        }, content_type=JSON)
        assert_no_500(r)

    def test_very_long_url(self, admin_client, company_id):
        url = "https://example.com/" + "a" * 10000
        r = admin_client.post("/api/documents", {
            "company_id": company_id, "name": "doc", "url": url,
        }, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Unicode / special characters
# ---------------------------------------------------------------------------


UNICODE_STRINGS = [
    "\u0000",                                # Null byte
    "\ud800".encode("utf-8", errors="replace").decode("utf-8"),  # Surrogate
    "\U0001F4A9",                            # Pile of poo emoji
    "\u202e\u0041\u0042\u0043",              # RTL override
    "Ñoño",                                  # Spanish
    "\u4e2d\u6587\u516c\u53f8",              # Chinese: 中文公司
    "\u0627\u0644\u0634\u0631\u0643\u0629",  # Arabic
    "О компании",                            # Russian
    "\n\r\t",                                # Whitespace chars
    "name=value&other=hack",                 # URL-encoded style
]


class TestUnicodeStrings:
    @pytest.mark.parametrize("text", UNICODE_STRINGS)
    def test_unicode_in_company_name(self, admin_client, text):
        r = admin_client.post("/api/companies", {
            "name": text, "country": "US", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)

    @pytest.mark.parametrize("text", UNICODE_STRINGS)
    def test_unicode_in_category(self, admin_client, text):
        r = admin_client.post("/api/categories", {"name": text}, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Missing required fields
# ---------------------------------------------------------------------------


class TestMissingFields:
    def test_company_no_name(self, admin_client):
        r = admin_client.post("/api/companies", {
            "country": "US", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_company_no_country(self, admin_client):
        r = admin_client.post("/api/companies", {
            "name": "X", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_holding_no_company_id(self, admin_client):
        r = admin_client.post("/api/holdings", {
            "asset": "Gold",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_transaction_no_amount(self, admin_client, company_id):
        r = admin_client.post("/api/transactions", {
            "company_id": company_id, "transaction_type": "buy",
            "description": "x", "date": "2025-01-01",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_liability_no_creditor(self, admin_client, company_id):
        r = admin_client.post("/api/liabilities", {
            "company_id": company_id, "liability_type": "loan", "principal": 1000,
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_custodian_no_asset_holding_id(self, admin_client):
        r = admin_client.post("/api/custodians", {
            "bank": "Test Bank",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400


# ---------------------------------------------------------------------------
# Invalid IDs
# ---------------------------------------------------------------------------


class TestInvalidIDs:
    def test_delete_nonexistent_company(self, admin_client):
        r = admin_client.delete("/api/companies/999999")
        assert_no_500(r)

    def test_update_nonexistent_company(self, admin_client):
        r = admin_client.put("/api/companies/999999", {"name": "X"}, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 404

    def test_delete_nonexistent_holding(self, admin_client):
        r = admin_client.delete("/api/holdings/999999")
        assert_no_500(r)

    def test_negative_id(self, admin_client):
        r = admin_client.delete("/api/companies/-1")
        assert_no_500(r)

    def test_zero_id(self, admin_client):
        r = admin_client.delete("/api/companies/0")
        assert_no_500(r)

    def test_holding_with_nonexistent_company(self, admin_client):
        r = admin_client.post("/api/holdings", {
            "company_id": 999999, "asset": "X",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_custodian_with_nonexistent_holding(self, admin_client):
        r = admin_client.post("/api/custodians", {
            "asset_holding_id": 999999, "bank": "X",
        }, content_type=JSON)
        assert_no_500(r)
        assert r.status_code == 400

    def test_string_as_id_in_url(self, admin_client):
        r = admin_client.delete("/api/companies/abc")
        assert_no_500(r)

    def test_very_large_id(self, admin_client):
        r = admin_client.delete("/api/companies/99999999999999999")
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Extra / unknown fields
# ---------------------------------------------------------------------------


class TestExtraFields:
    def test_extra_fields_ignored(self, admin_client):
        r = admin_client.post("/api/companies", {
            "name": "X", "country": "US", "category": "T",
            "nonexistent_field": "should be ignored",
            "admin_override": True,
            "__proto__": {"isAdmin": True},
        }, content_type=JSON)
        assert_no_500(r)

    def test_id_injection(self, admin_client):
        """Trying to set the ID manually should not work or at least not crash."""
        r = admin_client.post("/api/companies", {
            "id": 99999, "name": "X", "country": "US", "category": "T",
        }, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Content type edge cases
# ---------------------------------------------------------------------------


class TestContentTypes:
    def test_form_encoded_instead_of_json(self, admin_client):
        r = admin_client.post("/api/companies", {
            "name": "X", "country": "US", "category": "T",
        })
        assert_no_500(r)

    def test_xml_content_type(self, admin_client):
        r = admin_client.post(
            "/api/companies", "<company><name>X</name></company>",
            content_type="application/xml",
        )
        assert_no_500(r)

    def test_empty_content_type(self, admin_client):
        r = admin_client.post("/api/companies", b"", content_type="")
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Every list endpoint returns valid JSON
# ---------------------------------------------------------------------------

LIST_ENDPOINTS = [
    "/api/companies",
    "/api/holdings",
    "/api/documents",
    "/api/tax-deadlines",
    "/api/financials",
    "/api/categories",
    "/api/settings",
    "/api/bank-accounts",
    "/api/transactions",
    "/api/liabilities",
    "/api/service-providers",
    "/api/insurance-policies",
    "/api/board-meetings",
    "/api/audit-log",
    "/api/stats",
    "/api/export",
    "/api/entities",
    "/api/me",
    "/api/portfolio",
]


class TestAllEndpointsHealthy:
    @pytest.mark.parametrize("url", LIST_ENDPOINTS)
    def test_get_returns_200(self, admin_client, url):
        r = admin_client.get(url)
        assert r.status_code == 200
        # Must be valid JSON
        r.json()

    @pytest.mark.parametrize("url", LIST_ENDPOINTS)
    def test_unauthenticated_get_returns_403(self, db, url):
        client = Client()
        r = client.get(url)
        assert r.status_code == 403


# ---------------------------------------------------------------------------
# Rapid create-delete cycles (stability)
# ---------------------------------------------------------------------------


class TestRapidCycles:
    def test_rapid_create_delete(self, admin_client):
        """Create and immediately delete 100 companies."""
        for i in range(100):
            r = admin_client.post("/api/companies", {
                "name": f"Rapid-{i}", "country": "US", "category": "T",
            }, content_type=JSON)
            assert r.status_code == 201
            cid = r.json()["id"]
            r = admin_client.delete(f"/api/companies/{cid}")
            assert r.status_code == 200

        assert admin_client.get("/api/companies").json() == []

    def test_rapid_setting_updates(self, admin_client):
        """Overwrite the same setting 100 times."""
        for i in range(100):
            r = admin_client.put(
                "/api/settings/counter", {"value": str(i)}, content_type=JSON
            )
            assert r.status_code == 200

        r = admin_client.get("/api/settings")
        assert r.json()["counter"] == "99"


# ---------------------------------------------------------------------------
# JSON field injection (shareholders, directors, authorized_signers, etc.)
# ---------------------------------------------------------------------------


class TestJSONFieldInjection:
    def test_nested_objects_in_json_field(self, admin_client):
        r = admin_client.post("/api/companies", {
            "name": "JCo", "country": "US", "category": "T",
            "shareholders": [{"__class__": "hacked"}, None, 123, True],
            "directors": "not a list",
        }, content_type=JSON)
        assert_no_500(r)

    def test_huge_json_array(self, admin_client):
        r = admin_client.post("/api/companies", {
            "name": "BigCo", "country": "US", "category": "T",
            "shareholders": list(range(1000)),
        }, content_type=JSON)
        assert_no_500(r)

    def test_deeply_nested_json_field(self, admin_client, company_id):
        deep = {"a": {"b": {"c": {"d": "e"}}}}
        r = admin_client.post("/api/bank-accounts", {
            "company_id": company_id, "bank_name": "Test",
            "authorized_signers": [deep, deep, deep],
        }, content_type=JSON)
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Portfolio endpoint fuzz
# ---------------------------------------------------------------------------


class TestPortfolioFuzz:
    def test_portfolio_with_invalid_currency_param(self, admin_client):
        r = admin_client.get("/api/portfolio?currency=INVALID")
        assert_no_500(r)
        assert r.status_code == 200

    def test_portfolio_with_empty_currency(self, admin_client):
        r = admin_client.get("/api/portfolio?currency=")
        assert_no_500(r)

    def test_portfolio_with_sql_injection_currency(self, admin_client):
        r = admin_client.get("/api/portfolio?currency='; DROP TABLE core_company;--")
        assert_no_500(r)

    def test_portfolio_with_xss_currency(self, admin_client):
        r = admin_client.get("/api/portfolio?currency=<script>alert(1)</script>")
        assert_no_500(r)


# ---------------------------------------------------------------------------
# Asset type fuzz
# ---------------------------------------------------------------------------


class TestAssetTypeFuzz:
    def test_invalid_asset_type(self, admin_client, company_id):
        """Invalid asset_type should be rejected (not in choices)."""
        r = admin_client.post("/api/holdings", {
            "company_id": company_id, "asset": "Test",
            "asset_type": "not_a_real_type",
        }, content_type=JSON)
        assert_no_500(r)

    def test_empty_asset_type(self, admin_client, company_id):
        r = admin_client.post("/api/holdings", {
            "company_id": company_id, "asset": "Test",
            "asset_type": "",
        }, content_type=JSON)
        assert_no_500(r)

    def test_very_long_asset_type(self, admin_client, company_id):
        r = admin_client.post("/api/holdings", {
            "company_id": company_id, "asset": "Test",
            "asset_type": "x" * 10000,
        }, content_type=JSON)
        assert_no_500(r)

    def test_null_asset_type(self, admin_client, company_id):
        r = admin_client.post("/api/holdings", {
            "company_id": company_id, "asset": "Test",
            "asset_type": None,
        }, content_type=JSON)
        assert_no_500(r)

    def test_numeric_asset_type(self, admin_client, company_id):
        r = admin_client.post("/api/holdings", {
            "company_id": company_id, "asset": "Test",
            "asset_type": 12345,
        }, content_type=JSON)
        assert_no_500(r)
