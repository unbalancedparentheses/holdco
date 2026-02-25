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
