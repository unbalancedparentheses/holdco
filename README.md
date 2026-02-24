# Ergodic

Corporate structure, asset holdings, and custody tracking for the Ergodic group.

**26** entities across **4** countries.

Code: 8 | Finance: 5 | Culture: 5 | Craft: 7 | Holding: 1

---

This README is auto-generated from the SQLite database. Do not edit it directly.
Instead, edit via the admin panel and regenerate:

```
streamlit run app.py      # admin panel + dashboard
python generate_readme.py  # regenerate this file
```

## Architecture

| File | Purpose |
|---|---|
| `models.py` | Pydantic models — Company, Holding, AssetHolding, CustodianAccount |
| `db.py` | SQLite layer — CRUD operations, `get_entities()`, `export_json()` |
| `app.py` | Streamlit dashboard + admin panel for managing data |
| `yahoo.py` | Live asset prices from Yahoo Finance |
| `generate_readme.py` | Reads the database and generates this README |

The `db` module exposes a Python API (`db.insert_company(...)`, `db.export_json()`, etc.)
that AI agents or scripts can use directly.

## Dashboard

```
pip install -r requirements.txt
streamlit run app.py
```

**Dashboard tab**: corporate structure, live asset valuations, custodian details.

**Companies tab**: add, edit, and delete companies and holdings.

**Asset Holdings tab**: manage asset positions and custodian accounts.

## Planned

- QuickBooks API integration for real-time financials per entity

## Camiguin

| | |
|---|---|
| **Country** | Spain |
| **Category** | Holding |
| **Shareholders** | Federico Carrone |
| **Directors** | Martin Paulucci, Nicolas Urman |
| **Lawyer Studio** | Briz |

### Code (7)

| Entity      | Country   | Ownership % | Directors                   | Lawyer Studio |
|-------------|-----------|-------------|-----------------------------|---------------|
| Foltrek     | Uruguay   | 100%        | Juan Deal, Federico Carrone | PPV           |
| Lambda      | Argentina | 100%        |                             |               |
| Sur         | Argentina | 50%         |                             |               |
| FuzzingLabs | Argentina | 100%        |                             |               |
| Aligned     | Argentina | 100%        |                             |               |
| Sovra       | Argentina | 100%        |                             |               |
| Restolia    | Argentina | 100%        |                             |               |

#### Foltrek Holdings

| Asset | Ticker | Custodian Bank | Authorized Persons          |
|-------|--------|----------------|-----------------------------|
| Gold  | XAUUSD | Pershing       | Juan Deal, Federico Carrone |

### Finance (5)

| Entity       | Country   | Ownership % |
|--------------|-----------|-------------|
| 3MI Labs     | Argentina | 100%        |
| Ergodic Fund | Argentina | 100%        |
| Pol Finance  | Argentina | 100%        |
| Levenue      | Argentina | 100%        |
| Cresium      | Argentina | 100%        |

### Culture (5)

| Entity          | Country   | Ownership % |
|-----------------|-----------|-------------|
| 421             | Argentina | 100%        |
| Bellolandia     | Argentina | 100%        |
| LCB Game Studio | Argentina | 100%        |
| Lambda Forge    | Argentina | 100%        |
| Arcademy        | Argentina | 100%        |

### Craft (7)

| Entity               | Country   | Ownership % |
|----------------------|-----------|-------------|
| Burgschneider        | Europe/US | 100%        |
| Laderas de los Andes | Argentina | 100%        |
| Fruto Cafe           | Argentina | 100%        |
| High Mobility        | Argentina | 100%        |
| Ōtoro                | Argentina | 100%        |
| Palermo Wine Club    | Argentina | 100%        |
| Best Eleven          | Argentina | 100%        |

## Lambda SAS

| | |
|---|---|
| **Country** | Argentina |
| **Ownership %** | 100% |
| **Shareholders** | Pablo Perello, Juan Mazzoni, Martina Cantaro, Matias Onorato |
| **Directors** | Pablo Perello |
| **Lawyer Studio** | Croz |
