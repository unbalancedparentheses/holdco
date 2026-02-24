import streamlit as st

import db
from models import AssetHolding, Category, Company, Holding
from yahoo import get_price

db.init_db()

st.set_page_config(page_title="Ergodic", layout="wide")

page = st.sidebar.radio("Navigation", ["Dashboard", "Companies", "Asset Holdings"])


# --- Dashboard ---


def dashboard_page() -> None:
    st.title("Ergodic")
    entities = db.get_entities()
    stats = db.get_stats()

    # Summary metrics
    cols = st.columns(4)
    cols[0].metric("Total Entities", stats["total_companies"])
    cols[1].metric("Top-Level", stats["top_level_entities"])
    cols[2].metric("Subsidiaries", stats["subsidiaries"])
    cols[3].metric("Countries", len(stats["by_country"]))

    # Category breakdown
    cat_cols = st.columns(len(stats["by_category"]))
    for i, (cat, count) in enumerate(stats["by_category"].items()):
        cat_cols[i].metric(cat, count)

    st.divider()

    # Category filter
    all_cats = ["All"] + [c.value for c in Category]
    cat_filter = st.selectbox("Filter by category", all_cats, key="dash_cat_filter")

    for entity in entities:
        if isinstance(entity, Holding):
            st.header(entity.name)
            col1, col2, col3 = st.columns(3)
            col1.metric("Country", entity.country)
            col2.metric("Subsidiaries", len(entity.subsidiaries))
            col3.metric("Category", "Holding")

            subs = entity.subsidiaries
            if cat_filter != "All":
                subs = [s for s in subs if s.category.value == cat_filter]

            if subs:
                subs_data = []
                for s in subs:
                    subs_data.append({
                        "Entity": s.name,
                        "Country": s.country,
                        "Category": s.category.value,
                        "Ownership %": f"{s.ownership_pct}%" if s.ownership_pct is not None else "",
                        "Shareholders": ", ".join(s.shareholders) if s.shareholders else "",
                        "Directors": ", ".join(s.directors) if s.directors else "",
                        "Lawyer Studio": s.lawyer_studio or "",
                    })
                st.dataframe(subs_data, use_container_width=True, hide_index=True)
            elif cat_filter != "All":
                st.info(f"No {cat_filter} subsidiaries.")
        else:
            if cat_filter != "All" and entity.category.value != cat_filter:
                continue
            st.header(entity.name)
            col1, col2, col3 = st.columns(3)
            col1.metric("Country", entity.country)
            col2.metric("Ownership %", f"{entity.ownership_pct}%" if entity.ownership_pct is not None else "N/A")
            col3.metric("Lawyer Studio", entity.lawyer_studio or "N/A")

    # Asset Holdings with Live Prices
    all_holdings: list[tuple[str, AssetHolding]] = []
    for entity in entities:
        for h in entity.holdings:
            all_holdings.append((entity.name, h))
        if isinstance(entity, Holding):
            for sub in entity.subsidiaries:
                for h in sub.holdings:
                    all_holdings.append((sub.name, h))

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


# --- Companies Admin ---


def companies_page() -> None:
    st.title("Companies")

    rows = db.get_all_companies()

    table_data = []
    for r in rows:
        parent_name = ""
        if r["parent_id"]:
            for p in rows:
                if p["id"] == r["parent_id"]:
                    parent_name = p["name"]
                    break
        table_data.append({
            "ID": r["id"],
            "Name": r["name"],
            "Country": r["country"],
            "Category": r["category"],
            "Holding": "Yes" if r["is_holding"] else "",
            "Parent": parent_name,
            "Ownership %": f"{r['ownership_pct']}%" if r["ownership_pct"] is not None else "",
            "Shareholders": r["shareholders"] or "",
            "Directors": r["directors"] or "",
            "Lawyer Studio": r["lawyer_studio"] or "",
        })

    st.dataframe(table_data, use_container_width=True, hide_index=True)

    # Add Company
    st.subheader("Add Company")
    with st.form("add_company", clear_on_submit=True):
        name = st.text_input("Name*")
        country = st.text_input("Country*")
        category = st.selectbox("Category*", [c.value for c in Category])
        is_holding = st.checkbox("Is Holding")

        holdings_list = [r for r in rows if r["is_holding"]]
        parent_options = ["(none)"] + [r["name"] for r in holdings_list]
        parent_choice = st.selectbox("Parent", parent_options)

        ownership_pct = st.number_input("Ownership %", min_value=0, max_value=100, value=100)
        legal_name = st.text_input("Legal Name")
        tax_id = st.text_input("Tax ID")
        shareholders = st.text_input("Shareholders (comma-separated)")
        directors = st.text_input("Directors (comma-separated)")
        lawyer_studio = st.text_input("Lawyer Studio")

        if st.form_submit_button("Add"):
            if not name or not country:
                st.error("Name and Country are required.")
            else:
                parent_id = None
                if parent_choice != "(none)":
                    parent_id = db.get_company_id(parent_choice)
                db.insert_company(
                    name=name,
                    country=country,
                    category=category,
                    is_holding=is_holding,
                    parent_id=parent_id,
                    ownership_pct=ownership_pct if ownership_pct > 0 else None,
                    legal_name=legal_name or None,
                    tax_id=tax_id or None,
                    shareholders=[s.strip() for s in shareholders.split(",") if s.strip()] if shareholders else None,
                    directors=[d.strip() for d in directors.split(",") if d.strip()] if directors else None,
                    lawyer_studio=lawyer_studio or None,
                )
                st.success(f"Added {name}")
                st.rerun()

    # Edit Company
    st.subheader("Edit Company")
    edit_options = [r["name"] for r in rows]
    if edit_options:
        edit_choice = st.selectbox("Select company to edit", edit_options, key="edit_select")
        selected = db.get_company_by_name(edit_choice)
        if selected:
            with st.form("edit_company"):
                new_name = st.text_input("Name", value=selected["name"])
                new_country = st.text_input("Country", value=selected["country"])
                new_category = st.selectbox(
                    "Category",
                    [c.value for c in Category],
                    index=[c.value for c in Category].index(selected["category"]),
                )
                new_holding = st.checkbox("Is Holding", value=bool(selected["is_holding"]))

                parent_options = ["(none)"] + [r["name"] for r in rows if r["is_holding"] and r["id"] != selected["id"]]
                current_parent = "(none)"
                if selected["parent_id"]:
                    for r in rows:
                        if r["id"] == selected["parent_id"]:
                            current_parent = r["name"]
                            break
                new_parent = st.selectbox(
                    "Parent",
                    parent_options,
                    index=parent_options.index(current_parent) if current_parent in parent_options else 0,
                )

                new_ownership = st.number_input(
                    "Ownership %", min_value=0, max_value=100,
                    value=selected["ownership_pct"] if selected["ownership_pct"] is not None else 0,
                )
                new_legal = st.text_input("Legal Name", value=selected["legal_name"] or "")
                new_tax = st.text_input("Tax ID", value=selected["tax_id"] or "")
                new_shareholders = st.text_input("Shareholders", value=selected["shareholders"] or "")
                new_directors = st.text_input("Directors", value=selected["directors"] or "")
                new_lawyer = st.text_input("Lawyer Studio", value=selected["lawyer_studio"] or "")

                if st.form_submit_button("Save"):
                    parent_id = None
                    if new_parent != "(none)":
                        parent_id = db.get_company_id(new_parent)
                    db.update_company(
                        selected["id"],
                        name=new_name,
                        country=new_country,
                        category=new_category,
                        is_holding=new_holding,
                        parent_id=parent_id,
                        ownership_pct=new_ownership if new_ownership > 0 else None,
                        legal_name=new_legal or None,
                        tax_id=new_tax or None,
                        shareholders=new_shareholders or None,
                        directors=new_directors or None,
                        lawyer_studio=new_lawyer or None,
                    )
                    st.success(f"Updated {new_name}")
                    st.rerun()

    # Delete Company
    st.subheader("Delete Company")
    with st.form("delete_company"):
        del_choice = st.selectbox("Select company to delete", edit_options, key="del_select")
        confirm = st.checkbox("I confirm deletion")
        if st.form_submit_button("Delete") and confirm:
            cid = db.get_company_id(del_choice)
            if cid:
                db.delete_company(cid)
                st.success(f"Deleted {del_choice}")
                st.rerun()


# --- Asset Holdings Admin ---


def asset_holdings_page() -> None:
    st.title("Asset Holdings")

    rows = db.get_all_asset_holdings_with_company()

    table_data = []
    for r in rows:
        cust = db.get_custodian_for_holding(r["id"])
        table_data.append({
            "ID": r["id"],
            "Company": r["company_name"],
            "Asset": r["asset"],
            "Ticker": r["ticker"] or "",
            "Quantity": r["quantity"] if r["quantity"] is not None else "",
            "Unit": r["unit"] or "",
            "Custodian Bank": cust["bank"] if cust else "",
            "Account Number": cust["account_number"] or "" if cust else "",
            "Account Type": cust["account_type"] or "" if cust else "",
            "Authorized": cust["authorized_persons"] or "" if cust else "",
        })

    st.dataframe(table_data, use_container_width=True, hide_index=True)

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    # Add Asset Holding
    st.subheader("Add Asset Holding")
    with st.form("add_holding", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        asset = st.text_input("Asset*")
        ticker = st.text_input("Ticker")
        quantity = st.number_input("Quantity", min_value=0.0, value=0.0, format="%.4f")
        unit = st.text_input("Unit")

        st.markdown("**Custodian (optional)**")
        bank = st.text_input("Custodian Bank")
        account_number = st.text_input("Account Number")
        account_type = st.text_input("Account Type")
        authorized = st.text_input("Authorized Persons (comma-separated)")

        if st.form_submit_button("Add"):
            if not asset:
                st.error("Asset is required.")
            else:
                cid = db.get_company_id(company)
                ah_id = db.insert_asset_holding(
                    company_id=cid,
                    asset=asset,
                    ticker=ticker or None,
                    quantity=quantity if quantity > 0 else None,
                    unit=unit or None,
                )
                if bank:
                    db.insert_custodian(
                        asset_holding_id=ah_id,
                        bank=bank,
                        account_number=account_number or None,
                        account_type=account_type or None,
                        authorized_persons=[a.strip() for a in authorized.split(",") if a.strip()] if authorized else None,
                    )
                st.success(f"Added {asset} holding for {company}")
                st.rerun()

    # Delete Asset Holding
    if rows:
        st.subheader("Delete Asset Holding")
        with st.form("delete_holding"):
            holding_options = {f"{r['company_name']} — {r['asset']} (ID {r['id']})": r["id"] for r in rows}
            del_choice = st.selectbox("Select holding to delete", list(holding_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_asset_holding(holding_options[del_choice])
                st.success("Deleted holding")
                st.rerun()


# --- Route ---

if page == "Dashboard":
    dashboard_page()
elif page == "Companies":
    companies_page()
elif page == "Asset Holdings":
    asset_holdings_page()
