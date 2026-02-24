import sqlite3
from pathlib import Path

from models import AssetHolding, Category, Company, CustodianAccount, Holding

DB_PATH = Path(__file__).parent / "ergodic.db"


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
            FOREIGN KEY (parent_id) REFERENCES companies(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS asset_holdings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            asset TEXT NOT NULL,
            ticker TEXT,
            quantity REAL,
            unit TEXT,
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
    """)
    conn.commit()
    conn.close()


# --- Read ---


def get_entities() -> list[Holding | Company]:
    conn = _conn()

    # Fetch top-level entities (no parent)
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
        category=Category(row["category"]),
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
        category=Category(row["category"]),
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
) -> int:
    conn = _conn()
    cur = conn.execute(
        """INSERT INTO companies
           (name, legal_name, country, category, is_holding, parent_id,
            ownership_pct, tax_id, shareholders, directors, lawyer_studio)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            name, legal_name, country, category, int(is_holding), parent_id,
            ownership_pct, tax_id,
            _join_csv(shareholders or []),
            _join_csv(directors or []),
            lawyer_studio,
        ),
    )
    conn.commit()
    row_id = cur.lastrowid
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
        "directors", "lawyer_studio",
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
    conn.commit()
    conn.close()


def delete_company(company_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM companies WHERE id = ?", (company_id,))
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
) -> int:
    conn = _conn()
    cur = conn.execute(
        """INSERT INTO asset_holdings (company_id, asset, ticker, quantity, unit)
           VALUES (?, ?, ?, ?, ?)""",
        (company_id, asset, ticker, quantity, unit),
    )
    conn.commit()
    row_id = cur.lastrowid
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
    allowed = {"asset", "ticker", "quantity", "unit", "company_id"}
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
    conn.commit()
    conn.close()


def delete_asset_holding(holding_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM asset_holdings WHERE id = ?", (holding_id,))
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
    conn.commit()
    row_id = cur.lastrowid
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
    conn.commit()
    conn.close()


def delete_custodian(custodian_id: int) -> None:
    conn = _conn()
    conn.execute("DELETE FROM custodian_accounts WHERE id = ?", (custodian_id,))
    conn.commit()
    conn.close()


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
        d["category"] = d["category"].value if hasattr(d["category"], "value") else d["category"]
        if isinstance(e, Holding):
            for sub in d.get("subsidiaries", []):
                sub["category"] = sub["category"].value if hasattr(sub["category"], "value") else sub["category"]
        result.append(d)
    return {"entities": result}


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

    conn.close()
    return {
        "total_companies": total,
        "top_level_entities": top_level,
        "subsidiaries": subsidiaries,
        "by_category": categories,
        "by_country": countries,
        "asset_holdings": holdings_count,
        "custodian_accounts": custodians_count,
    }
