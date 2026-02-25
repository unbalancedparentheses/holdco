from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

import db
from yahoo import get_price

db.init_db()

app = FastAPI(title=db.get_app_name() + " API", version="1.0.0")


# --- Request models ---


class CompanyCreate(BaseModel):
    name: str
    country: str
    category: str
    legal_name: str | None = None
    is_holding: bool = False
    parent_id: int | None = None
    ownership_pct: int | None = None
    tax_id: str | None = None
    shareholders: list[str] | None = None
    directors: list[str] | None = None
    lawyer_studio: str | None = None
    notes: str | None = None
    website: str | None = None


class CompanyUpdate(BaseModel):
    name: str | None = None
    country: str | None = None
    category: str | None = None
    legal_name: str | None = None
    is_holding: bool | None = None
    parent_id: int | None = None
    ownership_pct: int | None = None
    tax_id: str | None = None
    shareholders: list[str] | None = None
    directors: list[str] | None = None
    lawyer_studio: str | None = None
    notes: str | None = None
    website: str | None = None


class HoldingCreate(BaseModel):
    company_id: int
    asset: str
    ticker: str | None = None
    quantity: float | None = None
    unit: str | None = None
    currency: str = "USD"


class CustodianCreate(BaseModel):
    asset_holding_id: int
    bank: str
    account_number: str | None = None
    account_type: str | None = None
    authorized_persons: list[str] | None = None


class DocumentCreate(BaseModel):
    company_id: int
    name: str
    doc_type: str | None = None
    url: str | None = None
    notes: str | None = None


class TaxDeadlineCreate(BaseModel):
    company_id: int
    jurisdiction: str
    description: str
    due_date: str
    status: str = "pending"
    notes: str | None = None


class FinancialCreate(BaseModel):
    company_id: int
    period: str
    revenue: float = 0
    expenses: float = 0
    currency: str = "USD"
    notes: str | None = None


class CategoryCreate(BaseModel):
    name: str
    color: str = "#e0e0e0"


class SettingUpdate(BaseModel):
    value: str


class BankAccountCreate(BaseModel):
    company_id: int
    bank_name: str
    account_number: str | None = None
    iban: str | None = None
    swift: str | None = None
    currency: str = "USD"
    account_type: str = "operating"
    balance: float = 0
    authorized_signers: list[str] | None = None
    notes: str | None = None


class TransactionCreate(BaseModel):
    company_id: int
    transaction_type: str
    description: str
    amount: float
    date: str
    currency: str = "USD"
    counterparty: str | None = None
    asset_holding_id: int | None = None
    notes: str | None = None


class LiabilityCreate(BaseModel):
    company_id: int
    liability_type: str
    creditor: str
    principal: float
    currency: str = "USD"
    interest_rate: float | None = None
    maturity_date: str | None = None
    status: str = "active"
    notes: str | None = None


class ServiceProviderCreate(BaseModel):
    company_id: int
    role: str
    name: str
    firm: str | None = None
    email: str | None = None
    phone: str | None = None
    notes: str | None = None


class InsurancePolicyCreate(BaseModel):
    company_id: int
    policy_type: str
    provider: str
    policy_number: str | None = None
    coverage_amount: float | None = None
    premium: float | None = None
    currency: str = "USD"
    start_date: str | None = None
    expiry_date: str | None = None
    notes: str | None = None


class BoardMeetingCreate(BaseModel):
    company_id: int
    scheduled_date: str
    meeting_type: str = "regular"
    status: str = "scheduled"
    notes: str | None = None


# --- Entities ---


@app.get("/entities")
def get_entities():
    return db.export_json()


# --- Companies ---


@app.get("/companies")
def list_companies():
    rows = db.get_all_companies()
    return [dict(r) for r in rows]


@app.post("/companies", status_code=201)
def create_company(body: CompanyCreate):
    row_id = db.insert_company(
        name=body.name,
        country=body.country,
        category=body.category,
        legal_name=body.legal_name,
        is_holding=body.is_holding,
        parent_id=body.parent_id,
        ownership_pct=body.ownership_pct,
        tax_id=body.tax_id,
        shareholders=body.shareholders,
        directors=body.directors,
        lawyer_studio=body.lawyer_studio,
        notes=body.notes,
        website=body.website,
    )
    return {"id": row_id}


@app.put("/companies/{company_id}")
def update_company(company_id: int, body: CompanyUpdate):
    fields = {k: v for k, v in body.model_dump().items() if v is not None}
    if not fields:
        raise HTTPException(400, "No fields to update")
    db.update_company(company_id, **fields)
    return {"ok": True}


@app.delete("/companies/{company_id}")
def delete_company(company_id: int):
    db.delete_company(company_id)
    return {"ok": True}


# --- Asset Holdings ---


@app.get("/holdings")
def list_holdings():
    rows = db.get_all_asset_holdings_with_company()
    return [dict(r) for r in rows]


@app.post("/holdings", status_code=201)
def create_holding(body: HoldingCreate):
    row_id = db.insert_asset_holding(
        company_id=body.company_id,
        asset=body.asset,
        ticker=body.ticker,
        quantity=body.quantity,
        unit=body.unit,
        currency=body.currency,
    )
    return {"id": row_id}


@app.delete("/holdings/{holding_id}")
def delete_holding(holding_id: int):
    db.delete_asset_holding(holding_id)
    return {"ok": True}


# --- Custodians ---


@app.post("/custodians", status_code=201)
def create_custodian(body: CustodianCreate):
    row_id = db.insert_custodian(
        asset_holding_id=body.asset_holding_id,
        bank=body.bank,
        account_number=body.account_number,
        account_type=body.account_type,
        authorized_persons=body.authorized_persons,
    )
    return {"id": row_id}


@app.delete("/custodians/{custodian_id}")
def delete_custodian(custodian_id: int):
    db.delete_custodian(custodian_id)
    return {"ok": True}


# --- Documents ---


@app.get("/documents")
def list_documents():
    rows = db.get_documents()
    return [dict(r) for r in rows]


@app.post("/documents", status_code=201)
def create_document(body: DocumentCreate):
    row_id = db.insert_document(
        company_id=body.company_id,
        name=body.name,
        doc_type=body.doc_type,
        url=body.url,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/documents/{doc_id}")
def delete_document(doc_id: int):
    db.delete_document(doc_id)
    return {"ok": True}


# --- Tax Deadlines ---


@app.get("/tax-deadlines")
def list_tax_deadlines():
    rows = db.get_tax_deadlines()
    return [dict(r) for r in rows]


@app.post("/tax-deadlines", status_code=201)
def create_tax_deadline(body: TaxDeadlineCreate):
    row_id = db.insert_tax_deadline(
        company_id=body.company_id,
        jurisdiction=body.jurisdiction,
        description=body.description,
        due_date=body.due_date,
        status=body.status,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/tax-deadlines/{deadline_id}")
def delete_tax_deadline(deadline_id: int):
    db.delete_tax_deadline(deadline_id)
    return {"ok": True}


# --- Financials ---


@app.get("/financials")
def list_financials():
    rows = db.get_financials()
    return [dict(r) for r in rows]


@app.post("/financials", status_code=201)
def create_financial(body: FinancialCreate):
    row_id = db.insert_financial(
        company_id=body.company_id,
        period=body.period,
        revenue=body.revenue,
        expenses=body.expenses,
        currency=body.currency,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/financials/{financial_id}")
def delete_financial(financial_id: int):
    db.delete_financial(financial_id)
    return {"ok": True}


# --- Categories ---


@app.get("/categories")
def list_categories():
    return db.get_categories()


@app.post("/categories", status_code=201)
def create_category(body: CategoryCreate):
    row_id = db.insert_category(body.name, body.color)
    return {"id": row_id}


@app.delete("/categories/{category_id}")
def delete_category(category_id: int):
    db.delete_category(category_id)
    return {"ok": True}


# --- Settings ---


@app.get("/settings")
def get_settings():
    return db.get_all_settings()


@app.put("/settings/{key}")
def update_setting(key: str, body: SettingUpdate):
    db.set_setting(key, body.value)
    return {"ok": True}


# --- Bank Accounts ---


@app.get("/bank-accounts")
def list_bank_accounts():
    rows = db.get_bank_accounts()
    return [dict(r) for r in rows]


@app.post("/bank-accounts", status_code=201)
def create_bank_account(body: BankAccountCreate):
    row_id = db.insert_bank_account(
        company_id=body.company_id,
        bank_name=body.bank_name,
        account_number=body.account_number,
        iban=body.iban,
        swift=body.swift,
        currency=body.currency,
        account_type=body.account_type,
        balance=body.balance,
        authorized_signers=body.authorized_signers,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/bank-accounts/{account_id}")
def delete_bank_account(account_id: int):
    db.delete_bank_account(account_id)
    return {"ok": True}


# --- Transactions ---


@app.get("/transactions")
def list_transactions():
    rows = db.get_transactions()
    return [dict(r) for r in rows]


@app.post("/transactions", status_code=201)
def create_transaction(body: TransactionCreate):
    row_id = db.insert_transaction(
        company_id=body.company_id,
        transaction_type=body.transaction_type,
        description=body.description,
        amount=body.amount,
        date=body.date,
        currency=body.currency,
        counterparty=body.counterparty,
        asset_holding_id=body.asset_holding_id,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/transactions/{transaction_id}")
def delete_transaction(transaction_id: int):
    db.delete_transaction(transaction_id)
    return {"ok": True}


# --- Liabilities ---


@app.get("/liabilities")
def list_liabilities():
    rows = db.get_liabilities()
    return [dict(r) for r in rows]


@app.post("/liabilities", status_code=201)
def create_liability(body: LiabilityCreate):
    row_id = db.insert_liability(
        company_id=body.company_id,
        liability_type=body.liability_type,
        creditor=body.creditor,
        principal=body.principal,
        currency=body.currency,
        interest_rate=body.interest_rate,
        maturity_date=body.maturity_date,
        status=body.status,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/liabilities/{liability_id}")
def delete_liability(liability_id: int):
    db.delete_liability(liability_id)
    return {"ok": True}


# --- Service Providers ---


@app.get("/service-providers")
def list_service_providers():
    rows = db.get_service_providers()
    return [dict(r) for r in rows]


@app.post("/service-providers", status_code=201)
def create_service_provider(body: ServiceProviderCreate):
    row_id = db.insert_service_provider(
        company_id=body.company_id,
        role=body.role,
        name=body.name,
        firm=body.firm,
        email=body.email,
        phone=body.phone,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/service-providers/{provider_id}")
def delete_service_provider(provider_id: int):
    db.delete_service_provider(provider_id)
    return {"ok": True}


# --- Insurance Policies ---


@app.get("/insurance-policies")
def list_insurance_policies():
    rows = db.get_insurance_policies()
    return [dict(r) for r in rows]


@app.post("/insurance-policies", status_code=201)
def create_insurance_policy(body: InsurancePolicyCreate):
    row_id = db.insert_insurance_policy(
        company_id=body.company_id,
        policy_type=body.policy_type,
        provider=body.provider,
        policy_number=body.policy_number,
        coverage_amount=body.coverage_amount,
        premium=body.premium,
        currency=body.currency,
        start_date=body.start_date,
        expiry_date=body.expiry_date,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/insurance-policies/{policy_id}")
def delete_insurance_policy(policy_id: int):
    db.delete_insurance_policy(policy_id)
    return {"ok": True}


# --- Board Meetings ---


@app.get("/board-meetings")
def list_board_meetings():
    rows = db.get_board_meetings()
    return [dict(r) for r in rows]


@app.post("/board-meetings", status_code=201)
def create_board_meeting(body: BoardMeetingCreate):
    row_id = db.insert_board_meeting(
        company_id=body.company_id,
        scheduled_date=body.scheduled_date,
        meeting_type=body.meeting_type,
        status=body.status,
        notes=body.notes,
    )
    return {"id": row_id}


@app.delete("/board-meetings/{meeting_id}")
def delete_board_meeting(meeting_id: int):
    db.delete_board_meeting(meeting_id)
    return {"ok": True}


# --- Prices ---


@app.get("/prices/{ticker}")
def get_ticker_price(ticker: str):
    price = get_price(ticker, record=True)
    history = db.get_price_history(ticker, limit=30)
    return {
        "ticker": ticker,
        "price": price,
        "history": [dict(h) for h in history],
    }


# --- Audit & Stats ---


@app.get("/audit-log")
def get_audit_log(limit: int = 50):
    rows = db.get_audit_log(limit=limit)
    return [dict(r) for r in rows]


@app.get("/stats")
def get_stats():
    return db.get_stats()


@app.get("/export")
def export_all():
    return db.export_json()
