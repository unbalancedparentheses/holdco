import json
import os
import sqlite3
from datetime import date, datetime
from pathlib import Path

from models import AssetHolding, Company, CustodianAccount, Holding

DB_PATH = Path(os.environ.get("HOLDCO_DB", Path(__file__).parent / "holdco.db"))


def _conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def _split_csv(s: str | None) -> list[str]:
    if not s:
        return []
    return [x.strip() for x in s.split(",") if x.strip()]


def _join_csv(items: list[str]) -> str | None:
    if not items:
        return None
    return ", ".join(items)


def init_db() -> None:
    conn = _conn()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS companies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            legal_name TEXT,
            country TEXT NOT NULL,
            category TEXT NOT NULL,
            is_holding INTEGER DEFAULT 0,
            parent_id INTEGER,
            ownership_pct INTEGER,
            tax_id TEXT,
            shareholders TEXT,
            directors TEXT,
            lawyer_studio TEXT,
            notes TEXT,
            website TEXT,
            FOREIGN KEY (parent_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS asset_holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            asset TEXT NOT NULL,
            ticker TEXT,
            quantity REAL,
            unit TEXT,
            currency TEXT DEFAULT 'USD',
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS custodian_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            asset_holding_id INTEGER NOT NULL UNIQUE,
            bank TEXT NOT NULL,
            account_number TEXT,
            account_type TEXT,
            authorized_persons TEXT,
            FOREIGN KEY (asset_holding_id) REFERENCES asset_holdings(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            doc_type TEXT,
            url TEXT,
            notes TEXT,
            uploaded_at TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS tax_deadlines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            jurisdiction TEXT NOT NULL,
            description TEXT NOT NULL,
            due_date TEXT NOT NULL,
            status TEXT DEFAULT 'pending',
            notes TEXT,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS financials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            period TEXT NOT NULL,
            revenue REAL DEFAULT 0,
            expenses REAL DEFAULT 0,
            currency TEXT DEFAULT 'USD',
            notes TEXT,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS price_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticker TEXT NOT NULL,
            price REAL NOT NULL,
            currency TEXT DEFAULT 'USD',
            recorded_at TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT (datetime('now')),
            action TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id INTEGER,
            details TEXT
        );

        CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            color TEXT DEFAULT '#e0e0e0'
        );

        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    """)
    conn.commit()
    conn.close()


def _log(conn: sqlite3.Connection, action: str, table_name: str, record_id: int | None, details: str | None = None) -> None:
    conn.execute(
        "INSERT INTO audit_log (action, table_name, record_id, details) VALUES (?, ?, ?, ?)",
        (action, table_name, record_id, details),
    )


# --- Categories CRUD ---


def get_categories() -> list[dict]:
    conn = _conn()
    rows = conn.execute("SELECT * FROM categories ORDER BY id").fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_category_names() -> list[str]:
    return [c["name"] for c in get_categories()]


def insert_category(name: str, color: str = "#e0e0e0") -> int:
    conn = _conn()
    cur = conn.execute(
        "INSERT INTO categories (name, color) VALUES (?, ?)", (name, color)
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "categories", row_id, f"name={name}")
    conn.commit()
    conn.close()
    return row_id


def update_category(category_id: int, **kwargs) -> None:
    allowed = {"name", "color"}
    sets = []
    values = []
    for key, val in kwargs.items():
        if key not in allowed:
            raise ValueError(f"Unknown field: {key}")
        sets.append(f"{key} = ?")
        values.append(val)
    if not sets:
        return
    values.append(category_id)
    conn = _conn()
    conn.execute(f"UPDATE categories SET {', '.join(sets)} WHERE id = ?", values)
    _log(conn, "update", "categories", category_id, json.dumps(kwargs))
    conn.commit()
    conn.close()


def delete_category(category_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM categories WHERE id = ?", (category_id,))
    _log(conn, "delete", "categories", category_id)
    conn.commit()
    conn.close()


# --- Settings CRUD ---


def get_setting(key: str, default: str = "") -> str:
    conn = _conn()
    row = conn.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    conn.close()
    return row["value"] if row else default


def set_setting(key: str, value: str) -> None:
    conn = _conn()
    conn.execute(
        "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?",
        (key, value, value),
    )
    _log(conn, "upsert", "settings", None, f"{key}={value}")
    conn.commit()
    conn.close()


def get_all_settings() -> dict[str, str]:
    conn = _conn()
    rows = conn.execute("SELECT key, value FROM settings ORDER BY key").fetchall()
    conn.close()
    return {r["key"]: r["value"] for r in rows}


def get_app_name() -> str:
    return get_setting("app_name", "Holdco")


# --- Read ---


def get_entities() -> list[Holding | Company]:
    conn = _conn()
    top_rows = conn.execute(
        "SELECT * FROM companies WHERE parent_id IS NULL ORDER BY id"
    ).fetchall()

    entities: list[Holding | Company] = []
    for row in top_rows:
        if row["is_holding"]:
            entities.append(_build_holding(conn, row))
        else:
            entities.append(_build_company(conn, row))

    conn.close()
    return entities


def _build_holdings_list(conn: sqlite3.Connection, company_id: int) -> list[AssetHolding]:
    ah_rows = conn.execute(
        "SELECT * FROM asset_holdings WHERE company_id = ? ORDER BY id", (company_id,)
    ).fetchall()
    holdings = []
    for ah in ah_rows:
        custodian = None
        cust_row = conn.execute(
            "SELECT * FROM custodian_accounts WHERE asset_holding_id = ?", (ah["id"],)
        ).fetchone()
        if cust_row:
            custodian = CustodianAccount(
                bank=cust_row["bank"],
                account_number=cust_row["account_number"],
                account_type=cust_row["account_type"],
                authorized_persons=_split_csv(cust_row["authorized_persons"]),
            )
        holdings.append(AssetHolding(
            asset=ah["asset"],
            ticker=ah["ticker"],
            quantity=ah["quantity"],
            unit=ah["unit"],
            custodian=custodian,
        ))
    return holdings


def _build_company(conn: sqlite3.Connection, row: sqlite3.Row) -> Company:
    return Company(
        name=row["name"],
        legal_name=row["legal_name"],
        country=row["country"],
        category=row["category"],
        ownership_pct=row["ownership_pct"],
        tax_id=row["tax_id"],
        shareholders=_split_csv(row["shareholders"]),
        directors=_split_csv(row["directors"]),
        lawyer_studio=row["lawyer_studio"],
        holdings=_build_holdings_list(conn, row["id"]),
    )


def _build_holding(conn: sqlite3.Connection, row: sqlite3.Row) -> Holding:
    sub_rows = conn.execute(
        "SELECT * FROM companies WHERE parent_id = ? ORDER BY id", (row["id"],)
    ).fetchall()
    subsidiaries = [_build_company(conn, sr) for sr in sub_rows]

    return Holding(
        name=row["name"],
        legal_name=row["legal_name"],
        country=row["country"],
        category=row["category"],
        ownership_pct=row["ownership_pct"],
        tax_id=row["tax_id"],
        shareholders=_split_csv(row["shareholders"]),
        directors=_split_csv(row["directors"]),
        lawyer_studio=row["lawyer_studio"],
        holdings=_build_holdings_list(conn, row["id"]),
        subsidiaries=subsidiaries,
    )


# --- Company CRUD ---


def insert_company(
    name: str,
    country: str,
    category: str,
    *,
    legal_name: str | None = None,
    is_holding: bool = False,
    parent_id: int | None = None,
    ownership_pct: int | None = None,
    tax_id: str | None = None,
    shareholders: list[str] | None = None,
    directors: list[str] | None = None,
    lawyer_studio: str | None = None,
    notes: str | None = None,
    website: str | None = None,
) -> int:
    conn = _conn()
    cur = conn.execute(
        """INSERT INTO companies
           (name, legal_name, country, category, is_holding, parent_id,
            ownership_pct, tax_id, shareholders, directors, lawyer_studio,
            notes, website)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            name, legal_name, country, category, int(is_holding), parent_id,
            ownership_pct, tax_id,
            _join_csv(shareholders or []),
            _join_csv(directors or []),
            lawyer_studio, notes, website,
        ),
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "companies", row_id, f"name={name}")
    conn.commit()
    conn.close()
    return row_id


def get_company_id(name: str) -> int | None:
    conn = _conn()
    row = conn.execute("SELECT id FROM companies WHERE name = ?", (name,)).fetchone()
    conn.close()
    return row["id"] if row else None


def update_company(company_id: int, **kwargs) -> None:
    allowed = {
        "name", "legal_name", "country", "category", "is_holding",
        "parent_id", "ownership_pct", "tax_id", "shareholders",
        "directors", "lawyer_studio", "notes", "website",
    }
    sets = []
    values = []
    for key, val in kwargs.items():
        if key not in allowed:
            raise ValueError(f"Unknown field: {key}")
        if key in ("shareholders", "directors") and isinstance(val, list):
            val = _join_csv(val)
        if key == "is_holding" and isinstance(val, bool):
            val = int(val)
        sets.append(f"{key} = ?")
        values.append(val)

    if not sets:
        return

    values.append(company_id)
    conn = _conn()
    conn.execute(f"UPDATE companies SET {', '.join(sets)} WHERE id = ?", values)
    _log(conn, "update", "companies", company_id, json.dumps({k: str(v) for k, v in kwargs.items()}))
    conn.commit()
    conn.close()


def delete_company(company_id: int) -> None:
    conn = _conn()
    row = conn.execute("SELECT name FROM companies WHERE id = ?", (company_id,)).fetchone()
    conn.execute("DELETE FROM companies WHERE id = ?", (company_id,))
    _log(conn, "delete", "companies", company_id, f"name={row['name']}" if row else None)
    conn.commit()
    conn.close()


# --- Asset Holding CRUD ---


def insert_asset_holding(
    company_id: int,
    asset: str,
    *,
    ticker: str | None = None,
    quantity: float | None = None,
    unit: str | None = None,
    currency: str = "USD",
) -> int:
    conn = _conn()
    cur = conn.execute(
        """INSERT INTO asset_holdings (company_id, asset, ticker, quantity, unit, currency)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (company_id, asset, ticker, quantity, unit, currency),
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "asset_holdings", row_id, f"asset={asset}")
    conn.commit()
    conn.close()
    return row_id


def get_asset_holdings(company_id: int) -> list[sqlite3.Row]:
    conn = _conn()
    rows = conn.execute(
        "SELECT * FROM asset_holdings WHERE company_id = ? ORDER BY id", (company_id,)
    ).fetchall()
    conn.close()
    return rows


def update_asset_holding(holding_id: int, **kwargs) -> None:
    allowed = {"asset", "ticker", "quantity", "unit", "company_id", "currency"}
    sets = []
    values = []
    for key, val in kwargs.items():
        if key not in allowed:
            raise ValueError(f"Unknown field: {key}")
        sets.append(f"{key} = ?")
        values.append(val)

    if not sets:
        return

    values.append(holding_id)
    conn = _conn()
    conn.execute(f"UPDATE asset_holdings SET {', '.join(sets)} WHERE id = ?", values)
    _log(conn, "update", "asset_holdings", holding_id, json.dumps({k: str(v) for k, v in kwargs.items()}))
    conn.commit()
    conn.close()


def delete_asset_holding(holding_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM asset_holdings WHERE id = ?", (holding_id,))
    _log(conn, "delete", "asset_holdings", holding_id)
    conn.commit()
    conn.close()


# --- Custodian CRUD ---


def insert_custodian(
    asset_holding_id: int,
    bank: str,
    *,
    account_number: str | None = None,
    account_type: str | None = None,
    authorized_persons: list[str] | None = None,
) -> int:
    conn = _conn()
    cur = conn.execute(
        """INSERT INTO custodian_accounts
           (asset_holding_id, bank, account_number, account_type, authorized_persons)
           VALUES (?, ?, ?, ?, ?)""",
        (
            asset_holding_id, bank, account_number, account_type,
            _join_csv(authorized_persons or []),
        ),
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "custodian_accounts", row_id, f"bank={bank}")
    conn.commit()
    conn.close()
    return row_id


def update_custodian(custodian_id: int, **kwargs) -> None:
    allowed = {"bank", "account_number", "account_type", "authorized_persons"}
    sets = []
    values = []
    for key, val in kwargs.items():
        if key not in allowed:
            raise ValueError(f"Unknown field: {key}")
        if key == "authorized_persons" and isinstance(val, list):
            val = _join_csv(val)
        sets.append(f"{key} = ?")
        values.append(val)

    if not sets:
        return

    values.append(custodian_id)
    conn = _conn()
    conn.execute(f"UPDATE custodian_accounts SET {', '.join(sets)} WHERE id = ?", values)
    _log(conn, "update", "custodian_accounts", custodian_id, json.dumps({k: str(v) for k, v in kwargs.items()}))
    conn.commit()
    conn.close()


def delete_custodian(custodian_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM custodian_accounts WHERE id = ?", (custodian_id,))
    _log(conn, "delete", "custodian_accounts", custodian_id)
    conn.commit()
    conn.close()


# --- Documents CRUD ---


def insert_document(
    company_id: int,
    name: str,
    *,
    doc_type: str | None = None,
    url: str | None = None,
    notes: str | None = None,
) -> int:
    conn = _conn()
    cur = conn.execute(
        "INSERT INTO documents (company_id, name, doc_type, url, notes) VALUES (?, ?, ?, ?, ?)",
        (company_id, name, doc_type, url, notes),
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "documents", row_id, f"name={name}")
    conn.commit()
    conn.close()
    return row_id


def get_documents(company_id: int | None = None) -> list[sqlite3.Row]:
    conn = _conn()
    if company_id:
        rows = conn.execute(
            "SELECT d.*, c.name as company_name FROM documents d JOIN companies c ON d.company_id = c.id WHERE d.company_id = ? ORDER BY d.id",
            (company_id,),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT d.*, c.name as company_name FROM documents d JOIN companies c ON d.company_id = c.id ORDER BY d.id"
        ).fetchall()
    conn.close()
    return rows


def delete_document(doc_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM documents WHERE id = ?", (doc_id,))
    _log(conn, "delete", "documents", doc_id)
    conn.commit()
    conn.close()


# --- Tax Deadlines CRUD ---


def insert_tax_deadline(
    company_id: int,
    jurisdiction: str,
    description: str,
    due_date: str,
    *,
    status: str = "pending",
    notes: str | None = None,
) -> int:
    conn = _conn()
    cur = conn.execute(
        "INSERT INTO tax_deadlines (company_id, jurisdiction, description, due_date, status, notes) VALUES (?, ?, ?, ?, ?, ?)",
        (company_id, jurisdiction, description, due_date, status, notes),
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "tax_deadlines", row_id, f"desc={description}")
    conn.commit()
    conn.close()
    return row_id


def get_tax_deadlines(company_id: int | None = None) -> list[sqlite3.Row]:
    conn = _conn()
    if company_id:
        rows = conn.execute(
            "SELECT t.*, c.name as company_name FROM tax_deadlines t JOIN companies c ON t.company_id = c.id WHERE t.company_id = ? ORDER BY t.due_date",
            (company_id,),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT t.*, c.name as company_name FROM tax_deadlines t JOIN companies c ON t.company_id = c.id ORDER BY t.due_date"
        ).fetchall()
    conn.close()
    return rows


def update_tax_deadline(deadline_id: int, **kwargs) -> None:
    allowed = {"jurisdiction", "description", "due_date", "status", "notes", "company_id"}
    sets = []
    values = []
    for key, val in kwargs.items():
        if key not in allowed:
            raise ValueError(f"Unknown field: {key}")
        sets.append(f"{key} = ?")
        values.append(val)
    if not sets:
        return
    values.append(deadline_id)
    conn = _conn()
    conn.execute(f"UPDATE tax_deadlines SET {', '.join(sets)} WHERE id = ?", values)
    _log(conn, "update", "tax_deadlines", deadline_id, json.dumps({k: str(v) for k, v in kwargs.items()}))
    conn.commit()
    conn.close()


def delete_tax_deadline(deadline_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM tax_deadlines WHERE id = ?", (deadline_id,))
    _log(conn, "delete", "tax_deadlines", deadline_id)
    conn.commit()
    conn.close()


# --- Financials CRUD ---


def insert_financial(
    company_id: int,
    period: str,
    *,
    revenue: float = 0,
    expenses: float = 0,
    currency: str = "USD",
    notes: str | None = None,
) -> int:
    conn = _conn()
    cur = conn.execute(
        "INSERT INTO financials (company_id, period, revenue, expenses, currency, notes) VALUES (?, ?, ?, ?, ?, ?)",
        (company_id, period, revenue, expenses, currency, notes),
    )
    row_id = cur.lastrowid
    _log(conn, "insert", "financials", row_id, f"period={period}")
    conn.commit()
    conn.close()
    return row_id


def get_financials(company_id: int | None = None) -> list[sqlite3.Row]:
    conn = _conn()
    if company_id:
        rows = conn.execute(
            "SELECT f.*, c.name as company_name FROM financials f JOIN companies c ON f.company_id = c.id WHERE f.company_id = ? ORDER BY f.period DESC",
            (company_id,),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT f.*, c.name as company_name FROM financials f JOIN companies c ON f.company_id = c.id ORDER BY f.period DESC"
        ).fetchall()
    conn.close()
    return rows


def update_financial(financial_id: int, **kwargs) -> None:
    allowed = {"period", "revenue", "expenses", "currency", "notes", "company_id"}
    sets = []
    values = []
    for key, val in kwargs.items():
        if key not in allowed:
            raise ValueError(f"Unknown field: {key}")
        sets.append(f"{key} = ?")
        values.append(val)
    if not sets:
        return
    values.append(financial_id)
    conn = _conn()
    conn.execute(f"UPDATE financials SET {', '.join(sets)} WHERE id = ?", values)
    _log(conn, "update", "financials", financial_id, json.dumps({k: str(v) for k, v in kwargs.items()}))
    conn.commit()
    conn.close()


def delete_financial(financial_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM financials WHERE id = ?", (financial_id,))
    _log(conn, "delete", "financials", financial_id)
    conn.commit()
    conn.close()


# --- Price History ---


def record_price(ticker: str, price: float, currency: str = "USD") -> int:
    conn = _conn()
    cur = conn.execute(
        "INSERT INTO price_history (ticker, price, currency) VALUES (?, ?, ?)",
        (ticker, price, currency),
    )
    row_id = cur.lastrowid
    conn.commit()
    conn.close()
    return row_id


def get_price_history(ticker: str, limit: int = 30) -> list[sqlite3.Row]:
    conn = _conn()
    rows = conn.execute(
        "SELECT * FROM price_history WHERE ticker = ? ORDER BY recorded_at DESC LIMIT ?",
        (ticker, limit),
    ).fetchall()
    conn.close()
    return rows


def get_all_price_history(limit: int = 100) -> list[sqlite3.Row]:
    conn = _conn()
    rows = conn.execute(
        "SELECT * FROM price_history ORDER BY recorded_at DESC LIMIT ?", (limit,)
    ).fetchall()
    conn.close()
    return rows


# --- Audit Log ---


def get_audit_log(limit: int = 50) -> list[sqlite3.Row]:
    conn = _conn()
    rows = conn.execute(
        "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT ?", (limit,)
    ).fetchall()
    conn.close()
    return rows


# --- Query helpers ---


def get_all_companies() -> list[sqlite3.Row]:
    conn = _conn()
    rows = conn.execute("SELECT * FROM companies ORDER BY id").fetchall()
    conn.close()
    return rows


def get_company_by_name(name: str) -> sqlite3.Row | None:
    conn = _conn()
    row = conn.execute("SELECT * FROM companies WHERE name = ?", (name,)).fetchone()
    conn.close()
    return row


def get_all_asset_holdings_with_company() -> list[sqlite3.Row]:
    conn = _conn()
    rows = conn.execute("""
        SELECT ah.*, c.name as company_name
        FROM asset_holdings ah
        JOIN companies c ON ah.company_id = c.id
        ORDER BY ah.id
    """).fetchall()
    conn.close()
    return rows


def get_custodian_for_holding(asset_holding_id: int) -> sqlite3.Row | None:
    conn = _conn()
    row = conn.execute(
        "SELECT * FROM custodian_accounts WHERE asset_holding_id = ?",
        (asset_holding_id,),
    ).fetchone()
    conn.close()
    return row


def export_json() -> dict:
    """Export all data as a JSON-serializable dict."""
    entities = get_entities()
    result = []
    for e in entities:
        d = e.model_dump()
        if isinstance(e, Holding):
            for sub in d.get("subsidiaries", []):
                pass  # category is already a plain string
        result.append(d)

    docs = [dict(r) for r in get_documents()]
    deadlines = [dict(r) for r in get_tax_deadlines()]
    financials = [dict(r) for r in get_financials()]

    return {
        "entities": result,
        "documents": docs,
        "tax_deadlines": deadlines,
        "financials": financials,
    }


def get_stats() -> dict:
    """Return summary statistics about the corporate structure."""
    conn = _conn()
    total = conn.execute("SELECT COUNT(*) FROM companies").fetchone()[0]
    top_level = conn.execute("SELECT COUNT(*) FROM companies WHERE parent_id IS NULL").fetchone()[0]
    subsidiaries = conn.execute("SELECT COUNT(*) FROM companies WHERE parent_id IS NOT NULL").fetchone()[0]

    categories = {}
    for row in conn.execute(
        "SELECT category, COUNT(*) as cnt FROM companies GROUP BY category ORDER BY cnt DESC"
    ).fetchall():
        categories[row["category"]] = row["cnt"]

    countries = {}
    for row in conn.execute(
        "SELECT country, COUNT(*) as cnt FROM companies GROUP BY country ORDER BY cnt DESC"
    ).fetchall():
        countries[row["country"]] = row["cnt"]

    holdings_count = conn.execute("SELECT COUNT(*) FROM asset_holdings").fetchone()[0]
    custodians_count = conn.execute("SELECT COUNT(*) FROM custodian_accounts").fetchone()[0]
    docs_count = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    deadlines_count = conn.execute("SELECT COUNT(*) FROM tax_deadlines").fetchone()[0]

    conn.close()
    return {
        "total_companies": total,
        "top_level_entities": top_level,
        "subsidiaries": subsidiaries,
        "by_category": categories,
        "by_country": countries,
        "asset_holdings": holdings_count,
        "custodian_accounts": custodians_count,
        "documents": docs_count,
        "tax_deadlines": deadlines_count,
    }
