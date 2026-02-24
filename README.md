# Ergodic

Corporate structure, asset holdings, and custody tracking for the Ergodic group.

This README is auto-generated from typed Python data. Do not edit it directly.
Instead, edit `data.py` and run:

```
python generate_readme.py
```

## How it works

- `models.py` — Pydantic models with validation (Company, Holding, AssetHolding, CustodianAccount)
- `data.py` — All corporate and asset data as typed Python objects
- `generate_readme.py` — Reads `data.py` and generates this README

Pydantic enforces constraints at data entry time (e.g. ownership must be 0-100).

## Dashboard

Live Streamlit dashboard with asset prices from Yahoo Finance:

```
pip install -r requirements.txt
streamlit run app.py
```

Shows corporate structure, live asset valuations, custodian details,
and authorized persons for each holding.

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

### Subsidiaries

| Entity               | Legal Name | Country   | Category | Ownership % | Tax ID | Directors                   | Lawyer Studio |
|----------------------|------------|-----------|----------|-------------|--------|-----------------------------|---------------|
| Foltrek              |            | Uruguay   | Code     | 100%        |        | Juan Deal, Federico Carrone | PPV           |
| Lambda               |            | Argentina | Code     | 100%        |        |                             |               |
| Sur                  |            | Argentina | Code     | 50%         |        |                             |               |
| FuzzingLabs          |            | Argentina | Code     | 100%        |        |                             |               |
| Aligned              |            | Argentina | Code     | 100%        |        |                             |               |
| Sovra                |            | Argentina | Code     | 100%        |        |                             |               |
| Restolia             |            | Argentina | Code     | 100%        |        |                             |               |
| 3MI Labs             |            | Argentina | Finance  | 100%        |        |                             |               |
| Ergodic Fund         |            | Argentina | Finance  | 100%        |        |                             |               |
| Pol Finance          |            | Argentina | Finance  | 100%        |        |                             |               |
| Levenue              |            | Argentina | Finance  | 100%        |        |                             |               |
| Cresium              |            | Argentina | Finance  | 100%        |        |                             |               |
| 421                  |            | Argentina | Culture  | 100%        |        |                             |               |
| Bellolandia          |            | Argentina | Culture  | 100%        |        |                             |               |
| LCB Game Studio      |            | Argentina | Culture  | 100%        |        |                             |               |
| Lambda Forge         |            | Argentina | Culture  | 100%        |        |                             |               |
| Arcademy             |            | Argentina | Culture  | 100%        |        |                             |               |
| Burgschneider        |            | Europe/US | Craft    | 100%        |        |                             |               |
| Laderas de los Andes |            | Argentina | Craft    | 100%        |        |                             |               |
| Fruto Cafe           |            | Argentina | Craft    | 100%        |        |                             |               |
| High Mobility        |            | Argentina | Craft    | 100%        |        |                             |               |
| Ōtoro                |            | Argentina | Craft    | 100%        |        |                             |               |
| Palermo Wine Club    |            | Argentina | Craft    | 100%        |        |                             |               |
| Best Eleven          |            | Argentina | Craft    | 100%        |        |                             |               |

#### Foltrek Holdings

| Asset | Ticker | Quantity | Unit | Custodian Bank | Account Type | Authorized Persons          |
|-------|--------|----------|------|----------------|--------------|-----------------------------|
| Gold  | XAUUSD |          |      | Pershing       |              | Juan Deal, Federico Carrone |

## Lambda SAS

| | |
|---|---|
| **Country** | Argentina |
| **Ownership %** | 100% |
| **Shareholders** | Pablo Perello, Juan Mazzoni, Martina Cantaro, Matias Onorato |
| **Directors** | Pablo Perello |
| **Lawyer Studio** | Croz |
