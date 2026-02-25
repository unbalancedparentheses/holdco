import sqlite3

import pytest

import db
from models import Company, Holding


# --- init_db ---


def test_init_db(tmp_db):
    conn = sqlite3.connect(tmp_db)
    tables = {
        r[0]
        for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        ).fetchall()
    }
    conn.close()
    expected = {
        "asset_holdings",
        "audit_log",
        "bank_accounts",
        "board_meetings",
        "categories",
        "companies",
        "custodian_accounts",
        "documents",
        "financials",
        "insurance_policies",
        "liabilities",
        "price_history",
        "service_providers",
        "settings",
        "tax_deadlines",
        "transactions",
    }
    assert expected.issubset(tables)


# --- Settings CRUD ---


def test_settings_crud(tmp_db):
    assert db.get_setting("missing") == ""
    assert db.get_setting("missing", "fallback") == "fallback"

    db.set_setting("app_name", "TestApp")
    assert db.get_setting("app_name") == "TestApp"

    db.set_setting("app_name", "Updated")
    assert db.get_setting("app_name") == "Updated"

    db.set_setting("theme", "dark")
    settings = db.get_all_settings()
    assert settings == {"app_name": "Updated", "theme": "dark"}


def test_get_app_name_default(tmp_db):
    assert db.get_app_name() == "Holdco"


def test_get_app_name_custom(tmp_db):
    db.set_setting("app_name", "MyCo")
    assert db.get_app_name() == "MyCo"


# --- Categories CRUD ---


def test_categories_crud(tmp_db):
    assert db.get_categories() == []
    assert db.get_category_names() == []

    cat_id = db.insert_category("Tech", "#aabbcc")
    assert cat_id is not None

    cats = db.get_categories()
    assert len(cats) == 1
    assert cats[0]["name"] == "Tech"
    assert cats[0]["color"] == "#aabbcc"
    assert db.get_category_names() == ["Tech"]

    db.update_category(cat_id, name="Technology", color="#112233")
    cats = db.get_categories()
    assert cats[0]["name"] == "Technology"
    assert cats[0]["color"] == "#112233"

    db.delete_category(cat_id)
    assert db.get_categories() == []


def test_update_category_no_fields(tmp_db):
    cat_id = db.insert_category("X")
    db.update_category(cat_id)  # no kwargs — early return
    assert db.get_categories()[0]["name"] == "X"


def test_update_category_invalid_field(tmp_db):
    cat_id = db.insert_category("X")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_category(cat_id, bogus="val")


# --- Company CRUD ---


def test_company_crud(tmp_db):
    cid = db.insert_company(
        "Acme",
        "US",
        "Holding",
        legal_name="Acme Inc.",
        is_holding=True,
        tax_id="TX-123",
        shareholders=["Alice", "Bob"],
        directors=["Carol"],
        lawyer_studio="Law LLP",
        notes="test notes",
        website="https://acme.example.com",
    )
    assert cid is not None

    companies = db.get_all_companies()
    assert len(companies) == 1
    row = companies[0]
    assert row["name"] == "Acme"
    assert row["legal_name"] == "Acme Inc."
    assert row["is_holding"] == 1
    assert row["shareholders"] == "Alice, Bob"
    assert row["directors"] == "Carol"

    assert db.get_company_id("Acme") == cid
    assert db.get_company_id("NoSuch") is None

    by_name = db.get_company_by_name("Acme")
    assert by_name is not None
    assert by_name["country"] == "US"
    assert db.get_company_by_name("NoSuch") is None

    db.update_company(cid, name="Acme Corp", country="UK")
    assert db.get_company_by_name("Acme Corp")["country"] == "UK"

    db.delete_company(cid)
    assert db.get_all_companies() == []


def test_update_company_shareholders_list(tmp_db):
    cid = db.insert_company("Co", "US", "Tech")
    db.update_company(cid, shareholders=["X", "Y"])
    row = db.get_company_by_name("Co")
    assert row["shareholders"] == "X, Y"


def test_update_company_is_holding_bool(tmp_db):
    cid = db.insert_company("Co", "US", "Tech")
    db.update_company(cid, is_holding=True)
    row = db.get_company_by_name("Co")
    assert row["is_holding"] == 1


def test_update_company_no_fields(tmp_db):
    cid = db.insert_company("Co", "US", "Tech")
    db.update_company(cid)  # no kwargs
    assert db.get_company_by_name("Co") is not None


def test_update_company_invalid_field(tmp_db):
    cid = db.insert_company("Co", "US", "Tech")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_company(cid, bogus="val")


def test_delete_company_cascades(tmp_db):
    cid = db.insert_company("Parent", "US", "Holding", is_holding=True)
    db.insert_company("Child", "US", "Tech", parent_id=cid, ownership_pct=100)
    db.delete_company(cid)
    assert db.get_all_companies() == []


def test_insert_company_with_subsidiary(tmp_db):
    pid = db.insert_company("Parent", "US", "Holding", is_holding=True)
    sid = db.insert_company("Sub", "US", "Tech", parent_id=pid, ownership_pct=80)
    assert sid is not None
    companies = db.get_all_companies()
    assert len(companies) == 2


# --- Asset Holding CRUD ---


def test_asset_holding_crud(company_id):
    ah_id = db.insert_asset_holding(
        company_id, "Bitcoin", ticker="BTC", quantity=2.5, unit="BTC", currency="USD"
    )
    assert ah_id is not None

    holdings = db.get_asset_holdings(company_id)
    assert len(holdings) == 1
    assert holdings[0]["asset"] == "Bitcoin"
    assert holdings[0]["ticker"] == "BTC"
    assert holdings[0]["quantity"] == 2.5

    all_h = db.get_all_asset_holdings_with_company()
    assert len(all_h) == 1
    assert all_h[0]["company_name"] == "Test Corp"

    db.update_asset_holding(ah_id, quantity=5.0, ticker="BTC-USD")
    updated = db.get_asset_holdings(company_id)
    assert updated[0]["quantity"] == 5.0
    assert updated[0]["ticker"] == "BTC-USD"

    db.delete_asset_holding(ah_id)
    assert db.get_asset_holdings(company_id) == []


def test_update_asset_holding_no_fields(company_id):
    ah_id = db.insert_asset_holding(company_id, "Gold")
    db.update_asset_holding(ah_id)  # no kwargs
    assert db.get_asset_holdings(company_id)[0]["asset"] == "Gold"


def test_update_asset_holding_invalid_field(company_id):
    ah_id = db.insert_asset_holding(company_id, "Gold")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_asset_holding(ah_id, bogus="val")


# --- Custodian CRUD ---


def test_custodian_crud(company_id):
    ah_id = db.insert_asset_holding(company_id, "Gold")

    cust_id = db.insert_custodian(
        ah_id,
        "First Bank",
        account_number="1234",
        account_type="custody",
        authorized_persons=["Alice", "Bob"],
    )
    assert cust_id is not None

    cust = db.get_custodian_for_holding(ah_id)
    assert cust is not None
    assert cust["bank"] == "First Bank"
    assert cust["authorized_persons"] == "Alice, Bob"

    db.update_custodian(cust_id, bank="Second Bank")
    cust = db.get_custodian_for_holding(ah_id)
    assert cust["bank"] == "Second Bank"

    db.update_custodian(cust_id, authorized_persons=["Carol"])
    cust = db.get_custodian_for_holding(ah_id)
    assert cust["authorized_persons"] == "Carol"

    db.delete_custodian(cust_id)
    assert db.get_custodian_for_holding(ah_id) is None


def test_update_custodian_no_fields(company_id):
    ah_id = db.insert_asset_holding(company_id, "Gold")
    cust_id = db.insert_custodian(ah_id, "Bank")
    db.update_custodian(cust_id)
    assert db.get_custodian_for_holding(ah_id)["bank"] == "Bank"


def test_update_custodian_invalid_field(company_id):
    ah_id = db.insert_asset_holding(company_id, "Gold")
    cust_id = db.insert_custodian(ah_id, "Bank")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_custodian(cust_id, bogus="val")


# --- Documents CRUD ---


def test_documents_crud(company_id):
    doc_id = db.insert_document(
        company_id, "Charter", doc_type="legal", url="https://x.com", notes="main doc"
    )
    assert doc_id is not None

    docs = db.get_documents()
    assert len(docs) == 1
    assert docs[0]["name"] == "Charter"
    assert docs[0]["company_name"] == "Test Corp"

    docs_filtered = db.get_documents(company_id=company_id)
    assert len(docs_filtered) == 1

    db.delete_document(doc_id)
    assert db.get_documents() == []


# --- Tax Deadlines CRUD ---


def test_tax_deadlines_crud(company_id):
    td_id = db.insert_tax_deadline(
        company_id, "US", "Annual filing", "2025-04-15", status="pending", notes="IRS"
    )
    assert td_id is not None

    deadlines = db.get_tax_deadlines()
    assert len(deadlines) == 1
    assert deadlines[0]["jurisdiction"] == "US"
    assert deadlines[0]["company_name"] == "Test Corp"

    deadlines_filtered = db.get_tax_deadlines(company_id=company_id)
    assert len(deadlines_filtered) == 1

    db.update_tax_deadline(td_id, status="filed")
    assert db.get_tax_deadlines()[0]["status"] == "filed"

    db.delete_tax_deadline(td_id)
    assert db.get_tax_deadlines() == []


def test_update_tax_deadline_no_fields(company_id):
    td_id = db.insert_tax_deadline(company_id, "US", "Filing", "2025-04-15")
    db.update_tax_deadline(td_id)
    assert db.get_tax_deadlines()[0]["description"] == "Filing"


def test_update_tax_deadline_invalid_field(company_id):
    td_id = db.insert_tax_deadline(company_id, "US", "Filing", "2025-04-15")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_tax_deadline(td_id, bogus="val")


# --- Financials CRUD ---


def test_financials_crud(company_id):
    fin_id = db.insert_financial(
        company_id, "2024-Q4", revenue=100000, expenses=50000, currency="USD", notes="good"
    )
    assert fin_id is not None

    fins = db.get_financials()
    assert len(fins) == 1
    assert fins[0]["period"] == "2024-Q4"
    assert fins[0]["revenue"] == 100000
    assert fins[0]["company_name"] == "Test Corp"

    fins_filtered = db.get_financials(company_id=company_id)
    assert len(fins_filtered) == 1

    db.update_financial(fin_id, revenue=200000)
    assert db.get_financials()[0]["revenue"] == 200000

    db.delete_financial(fin_id)
    assert db.get_financials() == []


def test_update_financial_no_fields(company_id):
    fin_id = db.insert_financial(company_id, "2024-Q4")
    db.update_financial(fin_id)
    assert db.get_financials()[0]["period"] == "2024-Q4"


def test_update_financial_invalid_field(company_id):
    fin_id = db.insert_financial(company_id, "2024-Q4")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_financial(fin_id, bogus="val")


# --- Bank Accounts CRUD ---


def test_bank_accounts_crud(company_id):
    ba_id = db.insert_bank_account(
        company_id,
        "Chase",
        account_number="1234",
        iban="US123",
        swift="CHASEUS",
        currency="USD",
        account_type="operating",
        balance=50000,
        authorized_signers=["Alice", "Bob"],
        notes="main",
    )
    assert ba_id is not None

    accts = db.get_bank_accounts()
    assert len(accts) == 1
    assert accts[0]["bank_name"] == "Chase"
    assert accts[0]["authorized_signers"] == "Alice, Bob"
    assert accts[0]["company_name"] == "Test Corp"

    accts_filtered = db.get_bank_accounts(company_id=company_id)
    assert len(accts_filtered) == 1

    db.update_bank_account(ba_id, balance=60000)
    assert db.get_bank_accounts()[0]["balance"] == 60000

    db.update_bank_account(ba_id, authorized_signers=["Carol"])
    assert db.get_bank_accounts()[0]["authorized_signers"] == "Carol"

    db.delete_bank_account(ba_id)
    assert db.get_bank_accounts() == []


def test_update_bank_account_no_fields(company_id):
    ba_id = db.insert_bank_account(company_id, "Bank")
    db.update_bank_account(ba_id)
    assert db.get_bank_accounts()[0]["bank_name"] == "Bank"


def test_update_bank_account_invalid_field(company_id):
    ba_id = db.insert_bank_account(company_id, "Bank")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_bank_account(ba_id, bogus="val")


# --- Transactions CRUD ---


def test_transactions_crud(company_id):
    txn_id = db.insert_transaction(
        company_id,
        "dividend",
        "Q4 dividend",
        50000,
        "2025-01-15",
        currency="USD",
        counterparty="SubCo",
        notes="quarterly",
    )
    assert txn_id is not None

    txns = db.get_transactions()
    assert len(txns) == 1
    assert txns[0]["transaction_type"] == "dividend"
    assert txns[0]["amount"] == 50000
    assert txns[0]["company_name"] == "Test Corp"

    txns_filtered = db.get_transactions(company_id=company_id)
    assert len(txns_filtered) == 1

    db.delete_transaction(txn_id)
    assert db.get_transactions() == []


def test_transaction_with_asset_holding(company_id):
    ah_id = db.insert_asset_holding(company_id, "Gold")
    txn_id = db.insert_transaction(
        company_id, "buy", "Buy gold", 10000, "2025-01-20", asset_holding_id=ah_id
    )
    txn = db.get_transactions()[0]
    assert txn["asset_holding_id"] == ah_id


# --- Liabilities CRUD ---


def test_liabilities_crud(company_id):
    lia_id = db.insert_liability(
        company_id,
        "bank_loan",
        "Chase",
        500000,
        currency="USD",
        interest_rate=5.5,
        maturity_date="2027-06-30",
        status="active",
        notes="term loan",
    )
    assert lia_id is not None

    liabs = db.get_liabilities()
    assert len(liabs) == 1
    assert liabs[0]["creditor"] == "Chase"
    assert liabs[0]["principal"] == 500000
    assert liabs[0]["company_name"] == "Test Corp"

    liabs_filtered = db.get_liabilities(company_id=company_id)
    assert len(liabs_filtered) == 1

    db.update_liability(lia_id, principal=400000, status="paid")
    updated = db.get_liabilities()[0]
    assert updated["principal"] == 400000
    assert updated["status"] == "paid"

    db.delete_liability(lia_id)
    assert db.get_liabilities() == []


def test_update_liability_no_fields(company_id):
    lia_id = db.insert_liability(company_id, "loan", "Bank", 1000)
    db.update_liability(lia_id)
    assert db.get_liabilities()[0]["creditor"] == "Bank"


def test_update_liability_invalid_field(company_id):
    lia_id = db.insert_liability(company_id, "loan", "Bank", 1000)
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_liability(lia_id, bogus="val")


# --- Service Providers CRUD ---


def test_service_providers_crud(company_id):
    sp_id = db.insert_service_provider(
        company_id,
        "lawyer",
        "Sarah Johnson",
        firm="Johnson LLP",
        email="sarah@j.com",
        phone="+1-555-0100",
        notes="corporate",
    )
    assert sp_id is not None

    sps = db.get_service_providers()
    assert len(sps) == 1
    assert sps[0]["name"] == "Sarah Johnson"
    assert sps[0]["company_name"] == "Test Corp"

    sps_filtered = db.get_service_providers(company_id=company_id)
    assert len(sps_filtered) == 1

    db.delete_service_provider(sp_id)
    assert db.get_service_providers() == []


# --- Insurance Policies CRUD ---


def test_insurance_policies_crud(company_id):
    pol_id = db.insert_insurance_policy(
        company_id,
        "directors_officers",
        "AIG",
        policy_number="DO-001",
        coverage_amount=5000000,
        premium=25000,
        currency="USD",
        start_date="2025-01-01",
        expiry_date="2026-01-01",
        notes="D&O",
    )
    assert pol_id is not None

    pols = db.get_insurance_policies()
    assert len(pols) == 1
    assert pols[0]["provider"] == "AIG"
    assert pols[0]["company_name"] == "Test Corp"

    pols_filtered = db.get_insurance_policies(company_id=company_id)
    assert len(pols_filtered) == 1

    db.delete_insurance_policy(pol_id)
    assert db.get_insurance_policies() == []


# --- Board Meetings CRUD ---


def test_board_meetings_crud(company_id):
    mtg_id = db.insert_board_meeting(
        company_id,
        "2025-03-15",
        meeting_type="annual",
        status="scheduled",
        notes="AGM",
    )
    assert mtg_id is not None

    mtgs = db.get_board_meetings()
    assert len(mtgs) == 1
    assert mtgs[0]["meeting_type"] == "annual"
    assert mtgs[0]["company_name"] == "Test Corp"

    mtgs_filtered = db.get_board_meetings(company_id=company_id)
    assert len(mtgs_filtered) == 1

    db.update_board_meeting(mtg_id, status="completed")
    assert db.get_board_meetings()[0]["status"] == "completed"

    db.delete_board_meeting(mtg_id)
    assert db.get_board_meetings() == []


def test_update_board_meeting_no_fields(company_id):
    mtg_id = db.insert_board_meeting(company_id, "2025-03-15")
    db.update_board_meeting(mtg_id)
    assert db.get_board_meetings()[0]["scheduled_date"] == "2025-03-15"


def test_update_board_meeting_invalid_field(company_id):
    mtg_id = db.insert_board_meeting(company_id, "2025-03-15")
    with pytest.raises(ValueError, match="Unknown field"):
        db.update_board_meeting(mtg_id, bogus="val")


# --- Price History ---


def test_price_history(tmp_db):
    rid = db.record_price("BTC", 65000.0, "USD")
    assert rid is not None

    db.record_price("BTC", 66000.0, "USD")
    db.record_price("ETH", 3500.0, "USD")

    history = db.get_price_history("BTC")
    assert len(history) == 2
    prices = {h["price"] for h in history}
    assert prices == {65000.0, 66000.0}

    all_history = db.get_all_price_history()
    assert len(all_history) == 3

    limited = db.get_price_history("BTC", limit=1)
    assert len(limited) == 1


# --- Audit Log ---


def test_audit_log(tmp_db):
    cid = db.insert_company("AuditCo", "US", "Tech")
    db.update_company(cid, name="AuditCo2")
    db.delete_company(cid)

    log = db.get_audit_log()
    assert len(log) >= 3
    actions = [entry["action"] for entry in log]
    assert "insert" in actions
    assert "update" in actions
    assert "delete" in actions


def test_audit_log_limit(tmp_db):
    for i in range(5):
        db.insert_category(f"cat_{i}")

    log = db.get_audit_log(limit=2)
    assert len(log) == 2


# --- Stats ---


def test_get_stats(company_id):
    db.insert_asset_holding(company_id, "Gold")
    ah_id = db.insert_asset_holding(company_id, "Silver")
    db.insert_custodian(ah_id, "Bank")
    db.insert_document(company_id, "Doc")
    db.insert_tax_deadline(company_id, "US", "Filing", "2025-04-15")
    db.insert_financial(company_id, "2024-Q4")
    db.insert_bank_account(company_id, "Chase")
    db.insert_transaction(company_id, "buy", "Purchase", 1000, "2025-01-01")
    db.insert_liability(company_id, "loan", "Bank", 5000)
    db.insert_service_provider(company_id, "lawyer", "Alice")
    db.insert_insurance_policy(company_id, "D&O", "AIG")
    db.insert_board_meeting(company_id, "2025-03-15")

    stats = db.get_stats()
    assert stats["total_companies"] == 1
    assert stats["top_level_entities"] == 1
    assert stats["subsidiaries"] == 0
    assert stats["asset_holdings"] == 2
    assert stats["custodian_accounts"] == 1
    assert stats["documents"] == 1
    assert stats["tax_deadlines"] == 1
    assert stats["bank_accounts"] == 1
    assert stats["transactions"] == 1
    assert stats["liabilities"] == 1
    assert stats["service_providers"] == 1
    assert stats["insurance_policies"] == 1
    assert stats["board_meetings"] == 1
    assert stats["by_category"] == {"Technology": 1}
    assert stats["by_country"] == {"United States": 1}


# --- Export JSON ---


def test_export_json(company_id):
    db.insert_document(company_id, "Doc")
    db.insert_tax_deadline(company_id, "US", "Filing", "2025-04-15")
    db.insert_financial(company_id, "2024-Q4")
    db.insert_bank_account(company_id, "Chase")
    db.insert_transaction(company_id, "buy", "Purchase", 1000, "2025-01-01")
    db.insert_liability(company_id, "loan", "Bank", 5000)
    db.insert_service_provider(company_id, "lawyer", "Alice")
    db.insert_insurance_policy(company_id, "D&O", "AIG")
    db.insert_board_meeting(company_id, "2025-03-15")

    data = db.export_json()
    assert "entities" in data
    assert "documents" in data
    assert "tax_deadlines" in data
    assert "financials" in data
    assert "bank_accounts" in data
    assert "transactions" in data
    assert "liabilities" in data
    assert "service_providers" in data
    assert "insurance_policies" in data
    assert "board_meetings" in data

    assert len(data["entities"]) == 1
    assert len(data["documents"]) == 1


# --- get_entities ---


def test_get_entities_company(tmp_db):
    db.insert_company("Standalone", "US", "Tech")
    entities = db.get_entities()
    assert len(entities) == 1
    assert isinstance(entities[0], Company)
    assert entities[0].name == "Standalone"


def test_get_entities_holding_with_subsidiaries(tmp_db):
    pid = db.insert_company("HoldCo", "US", "Holding", is_holding=True)
    db.insert_company("SubCo", "US", "Tech", parent_id=pid, ownership_pct=100)
    ah_id = db.insert_asset_holding(pid, "Gold", ticker="XAUUSD", quantity=10, unit="oz")
    db.insert_custodian(ah_id, "Vault Bank", account_type="custody", authorized_persons=["Alice"])

    entities = db.get_entities()
    assert len(entities) == 1
    holding = entities[0]
    assert isinstance(holding, Holding)
    assert holding.name == "HoldCo"
    assert len(holding.subsidiaries) == 1
    assert holding.subsidiaries[0].name == "SubCo"
    assert len(holding.holdings) == 1
    assert holding.holdings[0].asset == "Gold"
    assert holding.holdings[0].custodian is not None
    assert holding.holdings[0].custodian.bank == "Vault Bank"


# --- Export with Holding ---


def test_export_json_with_holding(tmp_db):
    pid = db.insert_company("HoldCo", "US", "Holding", is_holding=True)
    db.insert_company("SubCo", "US", "Tech", parent_id=pid)

    data = db.export_json()
    assert len(data["entities"]) == 1
    entity = data["entities"][0]
    assert "subsidiaries" in entity
    assert len(entity["subsidiaries"]) == 1
