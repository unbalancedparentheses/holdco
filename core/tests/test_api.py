import pytest
from django.test import Client


@pytest.fixture
def client(db):
    return Client()


@pytest.fixture
def api_company(logged_in_client):
    r = logged_in_client.post(
        "/api/companies",
        {"name": "Co", "country": "US", "category": "T"},
        content_type="application/json",
    )
    return r.json()["id"]


# --- Unauthenticated access tests ---


def test_dashboard_requires_login(client):
    r = client.get("/")
    assert r.status_code == 302
    assert "/accounts/login/" in r.url


def test_api_requires_login(client):
    r = client.get("/api/companies")
    assert r.status_code == 403


def test_company_detail_requires_login(client, db):
    r = client.get("/company/1/")
    assert r.status_code == 302
    assert "/accounts/login/" in r.url


# --- Authenticated tests ---


def test_list_companies_empty(logged_in_client):
    r = logged_in_client.get("/api/companies")
    assert r.status_code == 200
    assert r.json() == []


def test_create_and_list_company(logged_in_client):
    r = logged_in_client.post(
        "/api/companies",
        {
            "name": "Acme", "country": "US", "category": "Tech",
            "legal_name": "Acme Inc.", "is_holding": True,
            "tax_id": "TX-1", "shareholders": ["A"], "directors": ["B"],
            "lawyer_studio": "Law", "notes": "n", "website": "https://a.com",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    assert r.json()["id"] is not None

    r = logged_in_client.get("/api/companies")
    assert len(r.json()) == 1
    assert r.json()[0]["name"] == "Acme"


def test_update_company(logged_in_client, api_company):
    r = logged_in_client.put(
        f"/api/companies/{api_company}",
        {"name": "Co2"},
        content_type="application/json",
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    r = logged_in_client.get("/api/companies")
    assert r.json()[0]["name"] == "Co2"


def test_update_company_no_fields(logged_in_client, api_company):
    r = logged_in_client.put(
        f"/api/companies/{api_company}",
        {},
        content_type="application/json",
    )
    assert r.status_code == 400


def test_delete_company(logged_in_client, api_company):
    r = logged_in_client.delete(f"/api/companies/{api_company}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/companies").json() == []


def test_holdings_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/holdings",
        {
            "company_id": api_company, "asset": "Bitcoin", "ticker": "BTC",
            "quantity": 2.5, "unit": "BTC", "currency": "USD",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    hid = r.json()["id"]

    r = logged_in_client.get("/api/holdings")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["asset"] == "Bitcoin"

    r = logged_in_client.delete(f"/api/holdings/{hid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/holdings").json() == []


def test_custodians_crud(logged_in_client, api_company):
    hid = logged_in_client.post(
        "/api/holdings",
        {"company_id": api_company, "asset": "Gold"},
        content_type="application/json",
    ).json()["id"]

    r = logged_in_client.post(
        "/api/custodians",
        {
            "asset_holding_id": hid, "bank": "First Bank",
            "account_number": "1234", "account_type": "custody",
            "authorized_persons": ["Alice"],
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    cust_id = r.json()["id"]

    r = logged_in_client.delete(f"/api/custodians/{cust_id}")
    assert r.status_code == 200


def test_documents_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/documents",
        {
            "company_id": api_company, "name": "Charter",
            "doc_type": "legal", "url": "https://x.com", "notes": "main",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    did = r.json()["id"]

    r = logged_in_client.get("/api/documents")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/documents/{did}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/documents").json() == []


def test_tax_deadlines_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/tax-deadlines",
        {
            "company_id": api_company, "jurisdiction": "US",
            "description": "Annual", "due_date": "2025-04-15",
            "status": "pending", "notes": "IRS",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    tid = r.json()["id"]

    r = logged_in_client.get("/api/tax-deadlines")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/tax-deadlines/{tid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/tax-deadlines").json() == []


def test_financials_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/financials",
        {
            "company_id": api_company, "period": "2024-Q4",
            "revenue": 100000, "expenses": 50000,
            "currency": "USD", "notes": "good",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    fid = r.json()["id"]

    r = logged_in_client.get("/api/financials")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/financials/{fid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/financials").json() == []


def test_categories_crud(logged_in_client):
    r = logged_in_client.post(
        "/api/categories",
        {"name": "Tech", "color": "#aabbcc"},
        content_type="application/json",
    )
    assert r.status_code == 201
    cat_id = r.json()["id"]

    r = logged_in_client.get("/api/categories")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["name"] == "Tech"

    r = logged_in_client.delete(f"/api/categories/{cat_id}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/categories").json() == []


def test_settings_crud(logged_in_client):
    r = logged_in_client.get("/api/settings")
    assert r.status_code == 200
    assert r.json() == {}

    r = logged_in_client.put(
        "/api/settings/theme",
        {"value": "dark"},
        content_type="application/json",
    )
    assert r.status_code == 200

    r = logged_in_client.get("/api/settings")
    assert r.json() == {"theme": "dark"}


def test_bank_accounts_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/bank-accounts",
        {
            "company_id": api_company, "bank_name": "Chase",
            "account_number": "1234", "iban": "US123", "swift": "CHASEUS",
            "currency": "USD", "account_type": "operating",
            "balance": 50000, "authorized_signers": ["Alice"], "notes": "main",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    aid = r.json()["id"]

    r = logged_in_client.get("/api/bank-accounts")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/bank-accounts/{aid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/bank-accounts").json() == []


def test_transactions_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/transactions",
        {
            "company_id": api_company, "transaction_type": "dividend",
            "description": "Q4", "amount": 50000, "date": "2025-01-15",
            "currency": "USD", "counterparty": "Sub", "notes": "q",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    tid = r.json()["id"]

    r = logged_in_client.get("/api/transactions")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/transactions/{tid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/transactions").json() == []


def test_liabilities_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/liabilities",
        {
            "company_id": api_company, "liability_type": "loan",
            "creditor": "Chase", "principal": 500000,
            "currency": "USD", "interest_rate": 5.5,
            "maturity_date": "2027-06-30", "status": "active", "notes": "term",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    lid = r.json()["id"]

    r = logged_in_client.get("/api/liabilities")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/liabilities/{lid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/liabilities").json() == []


def test_service_providers_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/service-providers",
        {
            "company_id": api_company, "role": "lawyer", "name": "Sarah",
            "firm": "LLP", "email": "s@e.com", "phone": "+1", "notes": "corp",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    sid = r.json()["id"]

    r = logged_in_client.get("/api/service-providers")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/service-providers/{sid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/service-providers").json() == []


def test_insurance_policies_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/insurance-policies",
        {
            "company_id": api_company, "policy_type": "D&O", "provider": "AIG",
            "policy_number": "DO-001", "coverage_amount": 5000000,
            "premium": 25000, "currency": "USD",
            "start_date": "2025-01-01", "expiry_date": "2026-01-01", "notes": "d&o",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    pid = r.json()["id"]

    r = logged_in_client.get("/api/insurance-policies")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/insurance-policies/{pid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/insurance-policies").json() == []


def test_board_meetings_crud(logged_in_client, api_company):
    r = logged_in_client.post(
        "/api/board-meetings",
        {
            "company_id": api_company, "scheduled_date": "2025-03-15",
            "meeting_type": "annual", "status": "scheduled", "notes": "AGM",
        },
        content_type="application/json",
    )
    assert r.status_code == 201
    mid = r.json()["id"]

    r = logged_in_client.get("/api/board-meetings")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = logged_in_client.delete(f"/api/board-meetings/{mid}")
    assert r.status_code == 200
    assert logged_in_client.get("/api/board-meetings").json() == []


def test_audit_log(logged_in_client):
    logged_in_client.post(
        "/api/companies",
        {"name": "Co", "country": "US", "category": "T"},
        content_type="application/json",
    )

    r = logged_in_client.get("/api/audit-log")
    assert r.status_code == 200
    assert len(r.json()) >= 1


def test_audit_log_limit(logged_in_client):
    for i in range(5):
        logged_in_client.post(
            "/api/categories",
            {"name": f"cat_{i}"},
            content_type="application/json",
        )

    r = logged_in_client.get("/api/audit-log?limit=2")
    assert r.status_code == 200
    assert len(r.json()) == 2


def test_stats(logged_in_client):
    r = logged_in_client.get("/api/stats")
    assert r.status_code == 200
    data = r.json()
    assert "total_companies" in data
    assert "by_category" in data


def test_export(logged_in_client):
    r = logged_in_client.get("/api/export")
    assert r.status_code == 200
    data = r.json()
    assert "entities" in data
    assert "documents" in data


def test_entities(logged_in_client):
    logged_in_client.post(
        "/api/companies",
        {"name": "HoldCo", "country": "US", "category": "Holding", "is_holding": True},
        content_type="application/json",
    )

    r = logged_in_client.get("/api/entities")
    assert r.status_code == 200
    data = r.json()
    assert "entities" in data


def test_dashboard_page(logged_in_client):
    r = logged_in_client.get("/")
    assert r.status_code == 200
    assert b"Corporate Overview" in r.content


@pytest.mark.django_db
def test_company_detail_page(logged_in_client, api_company):
    r = logged_in_client.get(f"/company/{api_company}/")
    assert r.status_code == 200
    assert b"Entity Details" in r.content
    assert b"Co" in r.content


@pytest.mark.django_db
def test_company_detail_page_404(logged_in_client):
    r = logged_in_client.get("/company/99999/")
    assert r.status_code == 404
