import streamlit as st

import db
from models import AssetHolding, Category, Company, Holding
from yahoo import get_price

db.init_db()

st.set_page_config(page_title="Ergodic", layout="wide")

page = st.sidebar.radio(
    "Navigation",
    ["Dashboard", "Companies", "Asset Holdings", "Documents", "Tax Calendar", "Financials", "Audit Log"],
)


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
                prices[ticker] = get_price(ticker, record=True)

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

        # Price history charts
        for ticker in tickers:
            history = db.get_price_history(ticker, limit=30)
            if len(history) >= 2:
                st.subheader(f"{ticker} Price History")
                chart_data = {
                    "date": [h["recorded_at"] for h in reversed(history)],
                    "price": [h["price"] for h in reversed(history)],
                }
                st.line_chart(chart_data, x="date", y="price")


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
            "Website": r["website"] or "",
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
        website = st.text_input("Website")
        notes = st.text_area("Notes")

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
                    website=website or None,
                    notes=notes or None,
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
                new_website = st.text_input("Website", value=selected["website"] or "")
                new_notes = st.text_area("Notes", value=selected["notes"] or "")

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
                        website=new_website or None,
                        notes=new_notes or None,
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
            "Currency": r["currency"] or "USD",
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
        currency = st.text_input("Currency", value="USD")

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
                    currency=currency or "USD",
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


# --- Documents ---


def documents_page() -> None:
    st.title("Documents")

    docs = db.get_documents()

    if docs:
        table_data = []
        for d in docs:
            table_data.append({
                "ID": d["id"],
                "Company": d["company_name"],
                "Document": d["name"],
                "Type": d["doc_type"] or "",
                "URL": d["url"] or "",
                "Notes": d["notes"] or "",
                "Uploaded": d["uploaded_at"] or "",
            })
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No documents yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Document")
    with st.form("add_document", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        name = st.text_input("Document Name*")
        doc_type = st.selectbox("Type", ["Contract", "Articles of Incorporation", "Tax Filing", "Agreement", "Other"])
        url = st.text_input("URL / Path")
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not name:
                st.error("Document name is required.")
            else:
                cid = db.get_company_id(company)
                db.insert_document(
                    company_id=cid,
                    name=name,
                    doc_type=doc_type,
                    url=url or None,
                    notes=notes or None,
                )
                st.success(f"Added document: {name}")
                st.rerun()

    if docs:
        st.subheader("Delete Document")
        with st.form("delete_document"):
            doc_options = {f"{d['company_name']} — {d['name']} (ID {d['id']})": d["id"] for d in docs}
            del_choice = st.selectbox("Select document to delete", list(doc_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_document(doc_options[del_choice])
                st.success("Deleted document")
                st.rerun()


# --- Tax Calendar ---


def tax_calendar_page() -> None:
    st.title("Tax Calendar")

    deadlines = db.get_tax_deadlines()

    if deadlines:
        # Show upcoming vs overdue
        from datetime import date

        overdue = []
        upcoming = []
        completed = []
        for d in deadlines:
            if d["status"] == "completed":
                completed.append(d)
            elif d["due_date"] < str(date.today()):
                overdue.append(d)
            else:
                upcoming.append(d)

        cols = st.columns(3)
        cols[0].metric("Upcoming", len(upcoming))
        cols[1].metric("Overdue", len(overdue))
        cols[2].metric("Completed", len(completed))

        if overdue:
            st.error(f"{len(overdue)} overdue deadline(s)")

        table_data = []
        for d in deadlines:
            table_data.append({
                "ID": d["id"],
                "Company": d["company_name"],
                "Jurisdiction": d["jurisdiction"],
                "Description": d["description"],
                "Due Date": d["due_date"],
                "Status": d["status"] or "pending",
                "Notes": d["notes"] or "",
            })
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No tax deadlines yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Tax Deadline")
    with st.form("add_deadline", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        jurisdiction = st.text_input("Jurisdiction*")
        description = st.text_input("Description*")
        due_date = st.date_input("Due Date*")
        status = st.selectbox("Status", ["pending", "in_progress", "completed"])
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not jurisdiction or not description:
                st.error("Jurisdiction and description are required.")
            else:
                cid = db.get_company_id(company)
                db.insert_tax_deadline(
                    company_id=cid,
                    jurisdiction=jurisdiction,
                    description=description,
                    due_date=str(due_date),
                    status=status,
                    notes=notes or None,
                )
                st.success(f"Added deadline: {description}")
                st.rerun()

    if deadlines:
        st.subheader("Update Status")
        with st.form("update_deadline"):
            dl_options = {f"{d['company_name']} — {d['description']} ({d['due_date']})": d["id"] for d in deadlines}
            dl_choice = st.selectbox("Select deadline", list(dl_options.keys()))
            new_status = st.selectbox("New Status", ["pending", "in_progress", "completed"])
            if st.form_submit_button("Update"):
                db.update_tax_deadline(dl_options[dl_choice], status=new_status)
                st.success("Updated status")
                st.rerun()

        st.subheader("Delete Tax Deadline")
        with st.form("delete_deadline"):
            dl_del_choice = st.selectbox("Select deadline to delete", list(dl_options.keys()), key="dl_del")
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_tax_deadline(dl_options[dl_del_choice])
                st.success("Deleted deadline")
                st.rerun()


# --- Financials ---


def financials_page() -> None:
    st.title("Financials")

    financials = db.get_financials()

    if financials:
        table_data = []
        total_revenue = 0.0
        total_expenses = 0.0
        for f in financials:
            rev = f["revenue"] or 0
            exp = f["expenses"] or 0
            net = rev - exp
            total_revenue += rev
            total_expenses += exp
            table_data.append({
                "ID": f["id"],
                "Company": f["company_name"],
                "Period": f["period"],
                "Revenue": f"${rev:,.0f}",
                "Expenses": f"${exp:,.0f}",
                "Net": f"${net:,.0f}",
                "Currency": f["currency"] or "USD",
                "Notes": f["notes"] or "",
            })

        cols = st.columns(3)
        cols[0].metric("Total Revenue", f"${total_revenue:,.0f}")
        cols[1].metric("Total Expenses", f"${total_expenses:,.0f}")
        cols[2].metric("Net", f"${total_revenue - total_expenses:,.0f}")

        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No financial records yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Financial Record")
    with st.form("add_financial", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        period = st.text_input("Period* (e.g. 2024-Q1, 2024-01)")
        revenue = st.number_input("Revenue", min_value=0.0, value=0.0, format="%.2f")
        expenses = st.number_input("Expenses", min_value=0.0, value=0.0, format="%.2f")
        currency = st.text_input("Currency", value="USD")
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not period:
                st.error("Period is required.")
            else:
                cid = db.get_company_id(company)
                db.insert_financial(
                    company_id=cid,
                    period=period,
                    revenue=revenue,
                    expenses=expenses,
                    currency=currency or "USD",
                    notes=notes or None,
                )
                st.success(f"Added financial record for {period}")
                st.rerun()

    if financials:
        st.subheader("Delete Financial Record")
        with st.form("delete_financial"):
            fin_options = {f"{f['company_name']} — {f['period']} (ID {f['id']})": f["id"] for f in financials}
            del_choice = st.selectbox("Select record to delete", list(fin_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_financial(fin_options[del_choice])
                st.success("Deleted record")
                st.rerun()


# --- Audit Log ---


def audit_log_page() -> None:
    st.title("Audit Log")

    log = db.get_audit_log(limit=100)

    if log:
        table_data = []
        for entry in log:
            table_data.append({
                "Timestamp": entry["timestamp"],
                "Action": entry["action"],
                "Table": entry["table_name"],
                "Record ID": entry["record_id"] or "",
                "Details": entry["details"] or "",
            })
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No audit log entries yet.")


# --- Route ---

if page == "Dashboard":
    dashboard_page()
elif page == "Companies":
    companies_page()
elif page == "Asset Holdings":
    asset_holdings_page()
elif page == "Documents":
    documents_page()
elif page == "Tax Calendar":
    tax_calendar_page()
elif page == "Financials":
    financials_page()
elif page == "Audit Log":
    audit_log_page()
