import db


def test_list_companies_empty(client):
    r = client.get("/companies")
    assert r.status_code == 200
    assert r.json() == []


def test_create_and_list_company(client):
    r = client.post("/companies", json={
        "name": "Acme", "country": "US", "category": "Tech",
        "legal_name": "Acme Inc.", "is_holding": True,
        "tax_id": "TX-1", "shareholders": ["A"], "directors": ["B"],
        "lawyer_studio": "Law", "notes": "n", "website": "https://a.com",
    })
    assert r.status_code == 201
    cid = r.json()["id"]
    assert cid is not None

    r = client.get("/companies")
    assert len(r.json()) == 1
    assert r.json()[0]["name"] == "Acme"


def test_update_company(client):
    r = client.post("/companies", json={"name": "Co", "country": "US", "category": "Tech"})
    cid = r.json()["id"]

    r = client.put(f"/companies/{cid}", json={"name": "Co2"})
    assert r.status_code == 200
    assert r.json()["ok"] is True

    r = client.get("/companies")
    assert r.json()[0]["name"] == "Co2"


def test_update_company_no_fields(client):
    r = client.post("/companies", json={"name": "Co", "country": "US", "category": "Tech"})
    cid = r.json()["id"]

    r = client.put(f"/companies/{cid}", json={})
    assert r.status_code == 400


def test_delete_company(client):
    r = client.post("/companies", json={"name": "Co", "country": "US", "category": "Tech"})
    cid = r.json()["id"]

    r = client.delete(f"/companies/{cid}")
    assert r.status_code == 200
    assert client.get("/companies").json() == []


def test_holdings_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/holdings", json={
        "company_id": cid, "asset": "Bitcoin", "ticker": "BTC",
        "quantity": 2.5, "unit": "BTC", "currency": "USD",
    })
    assert r.status_code == 201
    hid = r.json()["id"]

    r = client.get("/holdings")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["asset"] == "Bitcoin"

    r = client.delete(f"/holdings/{hid}")
    assert r.status_code == 200
    assert client.get("/holdings").json() == []


def test_custodians_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]
    hid = client.post("/holdings", json={"company_id": cid, "asset": "Gold"}).json()["id"]

    r = client.post("/custodians", json={
        "asset_holding_id": hid, "bank": "First Bank",
        "account_number": "1234", "account_type": "custody",
        "authorized_persons": ["Alice"],
    })
    assert r.status_code == 201
    cust_id = r.json()["id"]

    r = client.delete(f"/custodians/{cust_id}")
    assert r.status_code == 200


def test_documents_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/documents", json={
        "company_id": cid, "name": "Charter",
        "doc_type": "legal", "url": "https://x.com", "notes": "main",
    })
    assert r.status_code == 201
    did = r.json()["id"]

    r = client.get("/documents")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/documents/{did}")
    assert r.status_code == 200
    assert client.get("/documents").json() == []


def test_tax_deadlines_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/tax-deadlines", json={
        "company_id": cid, "jurisdiction": "US",
        "description": "Annual", "due_date": "2025-04-15",
        "status": "pending", "notes": "IRS",
    })
    assert r.status_code == 201
    tid = r.json()["id"]

    r = client.get("/tax-deadlines")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/tax-deadlines/{tid}")
    assert r.status_code == 200
    assert client.get("/tax-deadlines").json() == []


def test_financials_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/financials", json={
        "company_id": cid, "period": "2024-Q4",
        "revenue": 100000, "expenses": 50000,
        "currency": "USD", "notes": "good",
    })
    assert r.status_code == 201
    fid = r.json()["id"]

    r = client.get("/financials")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/financials/{fid}")
    assert r.status_code == 200
    assert client.get("/financials").json() == []


def test_categories_crud(client):
    r = client.post("/categories", json={"name": "Tech", "color": "#aabbcc"})
    assert r.status_code == 201
    cat_id = r.json()["id"]

    r = client.get("/categories")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["name"] == "Tech"

    r = client.delete(f"/categories/{cat_id}")
    assert r.status_code == 200
    assert client.get("/categories").json() == []


def test_settings_crud(client):
    r = client.get("/settings")
    assert r.status_code == 200
    assert r.json() == {}

    r = client.put("/settings/theme", json={"value": "dark"})
    assert r.status_code == 200

    r = client.get("/settings")
    assert r.json() == {"theme": "dark"}


def test_bank_accounts_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/bank-accounts", json={
        "company_id": cid, "bank_name": "Chase",
        "account_number": "1234", "iban": "US123", "swift": "CHASEUS",
        "currency": "USD", "account_type": "operating",
        "balance": 50000, "authorized_signers": ["Alice"], "notes": "main",
    })
    assert r.status_code == 201
    aid = r.json()["id"]

    r = client.get("/bank-accounts")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/bank-accounts/{aid}")
    assert r.status_code == 200
    assert client.get("/bank-accounts").json() == []


def test_transactions_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/transactions", json={
        "company_id": cid, "transaction_type": "dividend",
        "description": "Q4", "amount": 50000, "date": "2025-01-15",
        "currency": "USD", "counterparty": "Sub", "notes": "q",
    })
    assert r.status_code == 201
    tid = r.json()["id"]

    r = client.get("/transactions")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/transactions/{tid}")
    assert r.status_code == 200
    assert client.get("/transactions").json() == []


def test_liabilities_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/liabilities", json={
        "company_id": cid, "liability_type": "loan",
        "creditor": "Chase", "principal": 500000,
        "currency": "USD", "interest_rate": 5.5,
        "maturity_date": "2027-06-30", "status": "active", "notes": "term",
    })
    assert r.status_code == 201
    lid = r.json()["id"]

    r = client.get("/liabilities")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/liabilities/{lid}")
    assert r.status_code == 200
    assert client.get("/liabilities").json() == []


def test_service_providers_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/service-providers", json={
        "company_id": cid, "role": "lawyer", "name": "Sarah",
        "firm": "LLP", "email": "s@e.com", "phone": "+1", "notes": "corp",
    })
    assert r.status_code == 201
    sid = r.json()["id"]

    r = client.get("/service-providers")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/service-providers/{sid}")
    assert r.status_code == 200
    assert client.get("/service-providers").json() == []


def test_insurance_policies_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/insurance-policies", json={
        "company_id": cid, "policy_type": "D&O", "provider": "AIG",
        "policy_number": "DO-001", "coverage_amount": 5000000,
        "premium": 25000, "currency": "USD",
        "start_date": "2025-01-01", "expiry_date": "2026-01-01", "notes": "d&o",
    })
    assert r.status_code == 201
    pid = r.json()["id"]

    r = client.get("/insurance-policies")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/insurance-policies/{pid}")
    assert r.status_code == 200
    assert client.get("/insurance-policies").json() == []


def test_board_meetings_crud(client):
    cid = client.post("/companies", json={"name": "Co", "country": "US", "category": "T"}).json()["id"]

    r = client.post("/board-meetings", json={
        "company_id": cid, "scheduled_date": "2025-03-15",
        "meeting_type": "annual", "status": "scheduled", "notes": "AGM",
    })
    assert r.status_code == 201
    mid = r.json()["id"]

    r = client.get("/board-meetings")
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.delete(f"/board-meetings/{mid}")
    assert r.status_code == 200
    assert client.get("/board-meetings").json() == []


def test_audit_log(client):
    client.post("/companies", json={"name": "Co", "country": "US", "category": "T"})

    r = client.get("/audit-log")
    assert r.status_code == 200
    assert len(r.json()) >= 1


def test_audit_log_limit(client):
    for i in range(5):
        client.post("/categories", json={"name": f"cat_{i}"})

    r = client.get("/audit-log?limit=2")
    assert r.status_code == 200
    assert len(r.json()) == 2


def test_stats(client):
    r = client.get("/stats")
    assert r.status_code == 200
    data = r.json()
    assert "total_companies" in data
    assert "by_category" in data


def test_export(client):
    r = client.get("/export")
    assert r.status_code == 200
    data = r.json()
    assert "entities" in data
    assert "documents" in data


def test_entities(client):
    client.post("/companies", json={
        "name": "HoldCo", "country": "US", "category": "Holding", "is_holding": True,
    })

    r = client.get("/entities")
    assert r.status_code == 200
    data = r.json()
    assert "entities" in data
