import streamlit as st

from data import entities
from models import AssetHolding, Company, Holding
from yahoo import get_price


st.set_page_config(page_title="Ergodic", layout="wide")
st.title("Ergodic")


def collect_all_companies(entity: Holding | Company) -> list[Company]:
    companies = []
    if isinstance(entity, Holding):
        for sub in entity.subsidiaries:
            companies.append(sub)
    return companies


def collect_all_holdings() -> list[tuple[str, AssetHolding]]:
    results = []
    for entity in entities:
        for h in entity.holdings:
            results.append((entity.name, h))
        if isinstance(entity, Holding):
            for sub in entity.subsidiaries:
                for h in sub.holdings:
                    results.append((sub.name, h))
    return results


# --- Corporate Structure ---

for entity in entities:
    if isinstance(entity, Holding):
        st.header(entity.name)
        col1, col2, col3 = st.columns(3)
        col1.metric("Country", entity.country)
        col2.metric("Subsidiaries", len(entity.subsidiaries))
        col3.metric("Category", "Holding")

        subs_data = []
        for s in entity.subsidiaries:
            subs_data.append({
                "Entity": s.name,
                "Country": s.country,
                "Category": s.category.value,
                "Ownership %": f"{s.ownership_pct}%" if s.ownership_pct is not None else "",
                "Directors": ", ".join(s.directors) if s.directors else "",
                "Lawyer Studio": s.lawyer_studio or "",
            })
        st.dataframe(subs_data, use_container_width=True, hide_index=True)
    else:
        st.header(entity.name)
        col1, col2, col3 = st.columns(3)
        col1.metric("Country", entity.country)
        col2.metric("Ownership %", f"{entity.ownership_pct}%" if entity.ownership_pct is not None else "N/A")
        col3.metric("Lawyer Studio", entity.lawyer_studio or "N/A")


# --- Asset Holdings with Live Prices ---

all_holdings = collect_all_holdings()

if all_holdings:
    st.divider()
    st.header("Asset Holdings")

    tickers = list({h.ticker for _, h in all_holdings if h.ticker})

    with st.spinner("Fetching live prices..."):
        prices: dict[str, float | None] = {}
        for ticker in tickers:
            prices[ticker] = get_price(ticker)

    holdings_data = []
    total_value = 0.0
    for entity_name, h in all_holdings:
        price = prices.get(h.ticker) if h.ticker else None
        qty = h.quantity
        value = price * qty if price is not None and qty is not None else None
        if value is not None:
            total_value += value

        holdings_data.append({
            "Entity": entity_name,
            "Asset": h.asset,
            "Ticker": h.ticker or "",
            "Quantity": qty if qty is not None else "",
            "Unit": h.unit or "",
            "Live Price (USD)": f"${price:,.2f}" if price is not None else "N/A",
            "Value (USD)": f"${value:,.2f}" if value is not None else "N/A",
            "Custodian": h.custodian.bank if h.custodian else "",
            "Authorized": ", ".join(h.custodian.authorized_persons) if h.custodian else "",
        })

    if total_value > 0:
        st.metric("Total Portfolio Value (USD)", f"${total_value:,.2f}")

    st.dataframe(holdings_data, use_container_width=True, hide_index=True)
