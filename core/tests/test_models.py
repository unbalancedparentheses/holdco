import pytest

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


@pytest.fixture
def company(db):
    return Company.objects.create(name="Test Corp", country="United States", category="Technology")


# --- Settings CRUD ---


@pytest.mark.django_db
def test_settings_crud():
    assert Setting.objects.count() == 0
    Setting.objects.create(key="app_name", value="TestApp")
    assert Setting.objects.get(key="app_name").value == "TestApp"

    Setting.objects.filter(key="app_name").update(value="Updated")
    assert Setting.objects.get(key="app_name").value == "Updated"

    Setting.objects.create(key="theme", value="dark")
    settings = {s.key: s.value for s in Setting.objects.all()}
    assert settings == {"app_name": "Updated", "theme": "dark"}


# --- Categories CRUD ---


@pytest.mark.django_db
def test_categories_crud():
    assert Category.objects.count() == 0
    cat = Category.objects.create(name="Tech", color="#aabbcc")
    assert cat.id is not None

    cats = list(Category.objects.all())
    assert len(cats) == 1
    assert cats[0].name == "Tech"
    assert cats[0].color == "#aabbcc"

    cat.name = "Technology"
    cat.color = "#112233"
    cat.save()
    cat.refresh_from_db()
    assert cat.name == "Technology"
    assert cat.color == "#112233"

    cat.delete()
    assert Category.objects.count() == 0


# --- Company CRUD ---


@pytest.mark.django_db
def test_company_crud():
    c = Company.objects.create(
        name="Acme",
        country="US",
        category="Holding",
        legal_name="Acme Inc.",
        is_holding=True,
        tax_id="TX-123",
        shareholders=["Alice", "Bob"],
        directors=["Carol"],
        lawyer_studio="Law LLP",
        notes="test notes",
        website="https://acme.example.com",
    )
    assert c.id is not None

    companies = list(Company.objects.all())
    assert len(companies) == 1
    assert companies[0].name == "Acme"
    assert companies[0].legal_name == "Acme Inc."
    assert companies[0].is_holding is True
    assert companies[0].shareholders == ["Alice", "Bob"]
    assert companies[0].directors == ["Carol"]

    c.name = "Acme Corp"
    c.country = "UK"
    c.save()
    c.refresh_from_db()
    assert c.name == "Acme Corp"
    assert c.country == "UK"

    c.delete()
    assert Company.objects.count() == 0


@pytest.mark.django_db
def test_company_with_subsidiary():
    parent = Company.objects.create(name="Parent", country="US", category="Holding", is_holding=True)
    child = Company.objects.create(
        name="Child", country="US", category="Tech", parent=parent, ownership_pct=100
    )
    assert Company.objects.count() == 2
    assert parent.subsidiaries.count() == 1
    assert parent.subsidiaries.first().name == "Child"


@pytest.mark.django_db
def test_delete_company_cascades():
    parent = Company.objects.create(name="Parent", country="US", category="Holding", is_holding=True)
    Company.objects.create(name="Child", country="US", category="Tech", parent=parent, ownership_pct=100)
    parent.delete()
    assert Company.objects.count() == 0


# --- Asset Holding CRUD ---


def test_asset_holding_crud(company):
    ah = AssetHolding.objects.create(
        company=company, asset="Bitcoin", ticker="BTC", quantity=2.5, unit="BTC", currency="USD"
    )
    assert ah.id is not None

    holdings = list(AssetHolding.objects.filter(company=company))
    assert len(holdings) == 1
    assert holdings[0].asset == "Bitcoin"
    assert holdings[0].ticker == "BTC"
    assert holdings[0].quantity == 2.5

    ah.quantity = 5.0
    ah.ticker = "BTC-USD"
    ah.save()
    ah.refresh_from_db()
    assert ah.quantity == 5.0
    assert ah.ticker == "BTC-USD"

    ah.delete()
    assert AssetHolding.objects.filter(company=company).count() == 0


# --- Custodian CRUD ---


def test_custodian_crud(company):
    ah = AssetHolding.objects.create(company=company, asset="Gold")
    cust = CustodianAccount.objects.create(
        asset_holding=ah,
        bank="First Bank",
        account_number="1234",
        account_type="custody",
        authorized_persons=["Alice", "Bob"],
    )
    assert cust.id is not None
    assert cust.bank == "First Bank"
    assert cust.authorized_persons == ["Alice", "Bob"]

    cust.bank = "Second Bank"
    cust.save()
    cust.refresh_from_db()
    assert cust.bank == "Second Bank"

    cust.delete()
    assert not hasattr(ah, "custodian") or CustodianAccount.objects.filter(asset_holding=ah).count() == 0


# --- Documents CRUD ---


def test_documents_crud(company):
    doc = Document.objects.create(
        company=company, name="Charter", doc_type="legal", url="https://x.com", notes="main doc"
    )
    assert doc.id is not None

    docs = list(Document.objects.all())
    assert len(docs) == 1
    assert docs[0].name == "Charter"
    assert docs[0].company.name == "Test Corp"

    doc.delete()
    assert Document.objects.count() == 0


# --- Tax Deadlines CRUD ---


def test_tax_deadlines_crud(company):
    td = TaxDeadline.objects.create(
        company=company, jurisdiction="US", description="Annual filing",
        due_date="2025-04-15", status="pending", notes="IRS"
    )
    assert td.id is not None

    deadlines = list(TaxDeadline.objects.all())
    assert len(deadlines) == 1
    assert deadlines[0].jurisdiction == "US"

    td.status = "filed"
    td.save()
    td.refresh_from_db()
    assert td.status == "filed"

    td.delete()
    assert TaxDeadline.objects.count() == 0


# --- Financials CRUD ---


def test_financials_crud(company):
    fin = Financial.objects.create(
        company=company, period="2024-Q4", revenue=100000, expenses=50000, currency="USD", notes="good"
    )
    assert fin.id is not None

    fins = list(Financial.objects.all())
    assert len(fins) == 1
    assert fins[0].period == "2024-Q4"
    assert fins[0].revenue == 100000

    fin.revenue = 200000
    fin.save()
    fin.refresh_from_db()
    assert fin.revenue == 200000

    fin.delete()
    assert Financial.objects.count() == 0


# --- Bank Accounts CRUD ---


def test_bank_accounts_crud(company):
    ba = BankAccount.objects.create(
        company=company,
        bank_name="Chase",
        account_number="1234",
        iban="US123",
        swift="CHASEUS",
        currency="USD",
        account_type="operating",
        balance=50000,
        authorized_signers=["Alice", "Bob"],
        notes="main",
    )
    assert ba.id is not None

    accts = list(BankAccount.objects.all())
    assert len(accts) == 1
    assert accts[0].bank_name == "Chase"
    assert accts[0].authorized_signers == ["Alice", "Bob"]

    ba.balance = 60000
    ba.save()
    ba.refresh_from_db()
    assert ba.balance == 60000

    ba.delete()
    assert BankAccount.objects.count() == 0


# --- Transactions CRUD ---


def test_transactions_crud(company):
    txn = Transaction.objects.create(
        company=company,
        transaction_type="dividend",
        description="Q4 dividend",
        amount=50000,
        date="2025-01-15",
        currency="USD",
        counterparty="SubCo",
        notes="quarterly",
    )
    assert txn.id is not None

    txns = list(Transaction.objects.all())
    assert len(txns) == 1
    assert txns[0].transaction_type == "dividend"
    assert txns[0].amount == 50000

    txn.delete()
    assert Transaction.objects.count() == 0


def test_transaction_with_asset_holding(company):
    ah = AssetHolding.objects.create(company=company, asset="Gold")
    txn = Transaction.objects.create(
        company=company, transaction_type="buy", description="Buy gold",
        amount=10000, date="2025-01-20", asset_holding=ah
    )
    assert txn.asset_holding == ah


# --- Liabilities CRUD ---


def test_liabilities_crud(company):
    lia = Liability.objects.create(
        company=company,
        liability_type="bank_loan",
        creditor="Chase",
        principal=500000,
        currency="USD",
        interest_rate=5.5,
        maturity_date="2027-06-30",
        status="active",
        notes="term loan",
    )
    assert lia.id is not None

    liabs = list(Liability.objects.all())
    assert len(liabs) == 1
    assert liabs[0].creditor == "Chase"
    assert liabs[0].principal == 500000

    lia.principal = 400000
    lia.status = "paid"
    lia.save()
    lia.refresh_from_db()
    assert lia.principal == 400000
    assert lia.status == "paid"

    lia.delete()
    assert Liability.objects.count() == 0


# --- Service Providers CRUD ---


def test_service_providers_crud(company):
    sp = ServiceProvider.objects.create(
        company=company,
        role="lawyer",
        name="Sarah Johnson",
        firm="Johnson LLP",
        email="sarah@j.com",
        phone="+1-555-0100",
        notes="corporate",
    )
    assert sp.id is not None
    assert sp.name == "Sarah Johnson"

    sp.delete()
    assert ServiceProvider.objects.count() == 0


# --- Insurance Policies CRUD ---


def test_insurance_policies_crud(company):
    pol = InsurancePolicy.objects.create(
        company=company,
        policy_type="directors_officers",
        provider="AIG",
        policy_number="DO-001",
        coverage_amount=5000000,
        premium=25000,
        currency="USD",
        start_date="2025-01-01",
        expiry_date="2026-01-01",
        notes="D&O",
    )
    assert pol.id is not None
    assert pol.provider == "AIG"

    pol.delete()
    assert InsurancePolicy.objects.count() == 0


# --- Board Meetings CRUD ---


def test_board_meetings_crud(company):
    mtg = BoardMeeting.objects.create(
        company=company,
        meeting_type="annual",
        scheduled_date="2025-03-15",
        status="scheduled",
        notes="AGM",
    )
    assert mtg.id is not None
    assert mtg.meeting_type == "annual"

    mtg.status = "completed"
    mtg.save()
    mtg.refresh_from_db()
    assert mtg.status == "completed"

    mtg.delete()
    assert BoardMeeting.objects.count() == 0


# --- Price History ---


@pytest.mark.django_db
def test_price_history():
    PriceHistory.objects.create(ticker="BTC", price=65000.0, currency="USD")
    PriceHistory.objects.create(ticker="BTC", price=66000.0, currency="USD")
    PriceHistory.objects.create(ticker="ETH", price=3500.0, currency="USD")

    history = list(PriceHistory.objects.filter(ticker="BTC"))
    assert len(history) == 2
    prices = {h.price for h in history}
    assert prices == {65000.0, 66000.0}

    all_history = list(PriceHistory.objects.all())
    assert len(all_history) == 3


# --- Audit Log ---


@pytest.mark.django_db
def test_audit_log():
    c = Company.objects.create(name="AuditCo", country="US", category="Tech")
    c.name = "AuditCo2"
    c.save()
    c.delete()

    log = list(AuditLog.objects.all())
    assert len(log) >= 3
    actions = [entry.action for entry in log]
    assert "insert" in actions
    assert "update" in actions
    assert "delete" in actions


@pytest.mark.django_db
def test_audit_log_limit():
    for i in range(5):
        Category.objects.create(name=f"cat_{i}")

    log = list(AuditLog.objects.all()[:2])
    assert len(log) == 2


# --- Stats ---


def test_get_stats(company):
    AssetHolding.objects.create(company=company, asset="Gold")
    ah = AssetHolding.objects.create(company=company, asset="Silver")
    CustodianAccount.objects.create(asset_holding=ah, bank="Bank")
    Document.objects.create(company=company, name="Doc")
    TaxDeadline.objects.create(company=company, jurisdiction="US", description="Filing", due_date="2025-04-15")
    Financial.objects.create(company=company, period="2024-Q4")
    BankAccount.objects.create(company=company, bank_name="Chase")
    Transaction.objects.create(company=company, transaction_type="buy", description="Purchase", amount=1000, date="2025-01-01")
    Liability.objects.create(company=company, liability_type="loan", creditor="Bank", principal=5000)
    ServiceProvider.objects.create(company=company, role="lawyer", name="Alice")
    InsurancePolicy.objects.create(company=company, policy_type="D&O", provider="AIG")
    BoardMeeting.objects.create(company=company, scheduled_date="2025-03-15")

    assert Company.objects.count() == 1
    assert Company.objects.filter(parent__isnull=True).count() == 1
    assert Company.objects.filter(parent__isnull=False).count() == 0
    assert AssetHolding.objects.count() == 2
    assert CustodianAccount.objects.count() == 1
    assert Document.objects.count() == 1
    assert TaxDeadline.objects.count() == 1
    assert BankAccount.objects.count() == 1
    assert Transaction.objects.count() == 1
    assert Liability.objects.count() == 1
    assert ServiceProvider.objects.count() == 1
    assert InsurancePolicy.objects.count() == 1
    assert BoardMeeting.objects.count() == 1
