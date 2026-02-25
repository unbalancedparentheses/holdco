import streamlit as st

import db
from models import AssetHolding, Company, Holding
from yahoo import get_price

db.init_db()

app_name = db.get_app_name()

st.set_page_config(page_title=app_name, layout="wide")

page = st.sidebar.radio(
    "Navigation",
    ["Dashboard", "Companies", "Asset Holdings", "Bank Accounts", "Transactions", "Liabilities", "Documents", "Tax Calendar", "Financials", "Service Providers", "Insurance", "Board Meetings", "Audit Log", "Settings"],
)


# --- Dashboard ---


def dashboard_page() -> None:
    st.title(db.get_app_name())
    entities = db.get_entities()
    stats = db.get_stats()

    # Summary metrics
    cols = st.columns(4)
    cols[0].metric("Total Entities", stats["total_companies"])
    cols[1].metric("Top-Level", stats["top_level_entities"])
    cols[2].metric("Subsidiaries", stats["subsidiaries"])
    cols[3].metric("Countries", len(stats["by_country"]))

    # Category breakdown
    if stats["by_category"]:
        cat_cols = st.columns(len(stats["by_category"]))
        for i, (cat, count) in enumerate(stats["by_category"].items()):
            cat_cols[i].metric(cat, count)

    st.divider()

    # Category filter
    category_names = db.get_category_names()
    all_cats = ["All"] + category_names
    cat_filter = st.selectbox("Filter by category", all_cats, key="dash_cat_filter")

    for entity in entities:
        if isinstance(entity, Holding):
            st.header(entity.name)
            col1, col2, col3 = st.columns(3)
            col1.metric("Country", entity.country)
            col2.metric("Subsidiaries", len(entity.subsidiaries))
            col3.metric("Category", entity.category)

            subs = entity.subsidiaries
            if cat_filter != "All":
                subs = [s for s in subs if s.category == cat_filter]

            if subs:
                subs_data = []
                for s in subs:
                    subs_data.append({
                        "Entity": s.name,
                        "Country": s.country,
                        "Category": s.category,
                        "Ownership %": f"{s.ownership_pct}%" if s.ownership_pct is not None else "",
                        "Shareholders": ", ".join(s.shareholders) if s.shareholders else "",
                        "Directors": ", ".join(s.directors) if s.directors else "",
                        "Lawyer Studio": s.lawyer_studio or "",
                    })
                st.dataframe(subs_data, use_container_width=True, hide_index=True)
            elif cat_filter != "All":
                st.info(f"No {cat_filter} subsidiaries.")
        else:
            if cat_filter != "All" and entity.category != cat_filter:
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
    category_names = db.get_category_names()

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
        category = st.selectbox("Category*", category_names)
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
                cat_index = category_names.index(selected["category"]) if selected["category"] in category_names else 0
                new_category = st.selectbox("Category", category_names, index=cat_index)
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


# --- Settings ---


def settings_page() -> None:
    st.title("Settings")

    # App Settings
    st.subheader("General")
    with st.form("settings_form"):
        current_name = db.get_setting("app_name", "Holdco")
        current_tagline = db.get_setting("tagline", "")
        current_website = db.get_setting("website", "")

        new_app_name = st.text_input("App Name", value=current_name)
        new_tagline = st.text_input("Tagline", value=current_tagline)
        new_website = st.text_input("Website", value=current_website)

        if st.form_submit_button("Save Settings"):
            db.set_setting("app_name", new_app_name)
            db.set_setting("tagline", new_tagline)
            db.set_setting("website", new_website)
            st.success("Settings saved. Refresh to see title change.")
            st.rerun()

    # Categories
    st.subheader("Categories")
    categories = db.get_categories()

    if categories:
        cat_data = []
        for c in categories:
            cat_data.append({
                "ID": c["id"],
                "Name": c["name"],
                "Color": c["color"],
            })
        st.dataframe(cat_data, use_container_width=True, hide_index=True)

    # Add Category
    with st.form("add_category", clear_on_submit=True):
        cat_name = st.text_input("Category Name*")
        cat_color = st.color_picker("Color", value="#e0e0e0")
        if st.form_submit_button("Add Category"):
            if not cat_name:
                st.error("Category name is required.")
            else:
                db.insert_category(cat_name, cat_color)
                st.success(f"Added category: {cat_name}")
                st.rerun()

    # Delete Category
    if categories:
        with st.form("delete_category"):
            cat_options = {f"{c['name']} (ID {c['id']})": c["id"] for c in categories}
            del_choice = st.selectbox("Select category to delete", list(cat_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete Category") and confirm:
                db.delete_category(cat_options[del_choice])
                st.success("Deleted category")
                st.rerun()


# --- Bank Accounts ---


def bank_accounts_page() -> None:
    st.title("Bank Accounts")

    accounts = db.get_bank_accounts()

    if accounts:
        table_data = []
        total_balance = 0.0
        for a in accounts:
            bal = a["balance"] or 0
            total_balance += bal
            table_data.append({
                "ID": a["id"],
                "Company": a["company_name"],
                "Bank": a["bank_name"],
                "Account #": a["account_number"] or "",
                "IBAN": a["iban"] or "",
                "SWIFT": a["swift"] or "",
                "Currency": a["currency"] or "USD",
                "Type": a["account_type"] or "",
                "Balance": f"${bal:,.2f}",
                "Authorized Signers": a["authorized_signers"] or "",
            })

        st.metric("Total Balance", f"${total_balance:,.2f}")
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No bank accounts yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Bank Account")
    with st.form("add_bank_account", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        bank_name = st.text_input("Bank Name*")
        account_number = st.text_input("Account Number")
        iban = st.text_input("IBAN")
        swift = st.text_input("SWIFT/BIC")
        currency = st.text_input("Currency", value="USD")
        account_type = st.selectbox("Account Type", ["operating", "savings", "fx", "custody", "escrow"])
        balance = st.number_input("Balance", value=0.0, format="%.2f")
        authorized_signers = st.text_input("Authorized Signers (comma-separated)")
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not bank_name:
                st.error("Bank name is required.")
            else:
                cid = db.get_company_id(company)
                db.insert_bank_account(
                    company_id=cid,
                    bank_name=bank_name,
                    account_number=account_number or None,
                    iban=iban or None,
                    swift=swift or None,
                    currency=currency or "USD",
                    account_type=account_type,
                    balance=balance,
                    authorized_signers=[s.strip() for s in authorized_signers.split(",") if s.strip()] if authorized_signers else None,
                    notes=notes or None,
                )
                st.success(f"Added account at {bank_name}")
                st.rerun()

    if accounts:
        st.subheader("Delete Bank Account")
        with st.form("delete_bank_account"):
            acct_options = {f"{a['company_name']} — {a['bank_name']} ({a['account_type']}) (ID {a['id']})": a["id"] for a in accounts}
            del_choice = st.selectbox("Select account to delete", list(acct_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_bank_account(acct_options[del_choice])
                st.success("Deleted bank account")
                st.rerun()


# --- Transactions ---


def transactions_page() -> None:
    st.title("Transactions")

    txns = db.get_transactions()

    if txns:
        table_data = []
        for t in txns:
            table_data.append({
                "ID": t["id"],
                "Company": t["company_name"],
                "Type": t["transaction_type"],
                "Description": t["description"],
                "Amount": f"${t['amount']:,.2f}",
                "Currency": t["currency"] or "USD",
                "Counterparty": t["counterparty"] or "",
                "Date": t["date"],
                "Notes": t["notes"] or "",
            })
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No transactions yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Transaction")
    with st.form("add_transaction", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        transaction_type = st.selectbox("Type*", ["buy", "sell", "dividend", "interest", "fee", "transfer", "distribution", "capital_call", "other"])
        description = st.text_input("Description*")
        amount = st.number_input("Amount*", value=0.0, format="%.2f")
        currency = st.text_input("Currency", value="USD")
        counterparty = st.text_input("Counterparty")
        date = st.date_input("Date*")
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not description or amount == 0:
                st.error("Description and amount are required.")
            else:
                cid = db.get_company_id(company)
                db.insert_transaction(
                    company_id=cid,
                    transaction_type=transaction_type,
                    description=description,
                    amount=amount,
                    date=str(date),
                    currency=currency or "USD",
                    counterparty=counterparty or None,
                    notes=notes or None,
                )
                st.success(f"Added transaction: {description}")
                st.rerun()

    if txns:
        st.subheader("Delete Transaction")
        with st.form("delete_transaction"):
            txn_options = {f"{t['company_name']} — {t['description']} ({t['date']}) (ID {t['id']})": t["id"] for t in txns}
            del_choice = st.selectbox("Select transaction to delete", list(txn_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_transaction(txn_options[del_choice])
                st.success("Deleted transaction")
                st.rerun()


# --- Liabilities ---


def liabilities_page() -> None:
    st.title("Liabilities")

    liabilities = db.get_liabilities()

    if liabilities:
        table_data = []
        total_principal = 0.0
        for l in liabilities:
            p = l["principal"] or 0
            total_principal += p
            table_data.append({
                "ID": l["id"],
                "Company": l["company_name"],
                "Type": l["liability_type"],
                "Creditor": l["creditor"],
                "Principal": f"${p:,.2f}",
                "Currency": l["currency"] or "USD",
                "Interest Rate": f"{l['interest_rate']}%" if l["interest_rate"] is not None else "",
                "Maturity": l["maturity_date"] or "",
                "Status": l["status"] or "active",
            })
            total_principal += 0  # already added

        st.metric("Total Liabilities", f"${total_principal:,.2f}")
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No liabilities yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Liability")
    with st.form("add_liability", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        liability_type = st.selectbox("Type*", ["bank_loan", "bond", "credit_line", "lease", "intercompany", "other"])
        creditor = st.text_input("Creditor*")
        principal = st.number_input("Principal*", value=0.0, format="%.2f")
        currency = st.text_input("Currency", value="USD")
        interest_rate = st.number_input("Interest Rate (%)", value=0.0, format="%.2f")
        maturity_date = st.date_input("Maturity Date")
        status = st.selectbox("Status", ["active", "paid_off", "defaulted", "restructured"])
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not creditor or principal == 0:
                st.error("Creditor and principal are required.")
            else:
                cid = db.get_company_id(company)
                db.insert_liability(
                    company_id=cid,
                    liability_type=liability_type,
                    creditor=creditor,
                    principal=principal,
                    currency=currency or "USD",
                    interest_rate=interest_rate if interest_rate > 0 else None,
                    maturity_date=str(maturity_date),
                    status=status,
                    notes=notes or None,
                )
                st.success(f"Added liability: {creditor}")
                st.rerun()

    if liabilities:
        st.subheader("Delete Liability")
        with st.form("delete_liability"):
            lia_options = {f"{l['company_name']} — {l['creditor']} ({l['liability_type']}) (ID {l['id']})": l["id"] for l in liabilities}
            del_choice = st.selectbox("Select liability to delete", list(lia_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_liability(lia_options[del_choice])
                st.success("Deleted liability")
                st.rerun()


# --- Service Providers ---


def service_providers_page() -> None:
    st.title("Service Providers")

    providers = db.get_service_providers()

    if providers:
        table_data = []
        for p in providers:
            table_data.append({
                "ID": p["id"],
                "Company": p["company_name"],
                "Role": p["role"],
                "Name": p["name"],
                "Firm": p["firm"] or "",
                "Email": p["email"] or "",
                "Phone": p["phone"] or "",
                "Notes": p["notes"] or "",
            })
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No service providers yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Service Provider")
    with st.form("add_service_provider", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        role = st.selectbox("Role*", ["lawyer", "accountant", "auditor", "banker", "registered_agent", "tax_advisor", "consultant", "other"])
        name = st.text_input("Contact Name*")
        firm = st.text_input("Firm")
        email = st.text_input("Email")
        phone = st.text_input("Phone")
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not name:
                st.error("Contact name is required.")
            else:
                cid = db.get_company_id(company)
                db.insert_service_provider(
                    company_id=cid,
                    role=role,
                    name=name,
                    firm=firm or None,
                    email=email or None,
                    phone=phone or None,
                    notes=notes or None,
                )
                st.success(f"Added {role}: {name}")
                st.rerun()

    if providers:
        st.subheader("Delete Service Provider")
        with st.form("delete_service_provider"):
            prov_options = {f"{p['company_name']} — {p['name']} ({p['role']}) (ID {p['id']})": p["id"] for p in providers}
            del_choice = st.selectbox("Select provider to delete", list(prov_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_service_provider(prov_options[del_choice])
                st.success("Deleted service provider")
                st.rerun()


# --- Insurance Policies ---


def insurance_page() -> None:
    st.title("Insurance Policies")

    policies = db.get_insurance_policies()

    if policies:
        from datetime import date as dt_date
        table_data = []
        expiring_soon = 0
        for p in policies:
            is_expiring = p["expiry_date"] and p["expiry_date"] <= str(dt_date.today().replace(month=dt_date.today().month % 12 + 1))
            if is_expiring:
                expiring_soon += 1
            table_data.append({
                "ID": p["id"],
                "Company": p["company_name"],
                "Type": p["policy_type"],
                "Provider": p["provider"],
                "Policy #": p["policy_number"] or "",
                "Coverage": f"${p['coverage_amount']:,.2f}" if p["coverage_amount"] else "",
                "Premium": f"${p['premium']:,.2f}" if p["premium"] else "",
                "Currency": p["currency"] or "USD",
                "Start": p["start_date"] or "",
                "Expiry": p["expiry_date"] or "",
            })

        if expiring_soon > 0:
            st.warning(f"{expiring_soon} policy/policies expiring soon")
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No insurance policies yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Add Insurance Policy")
    with st.form("add_insurance", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        policy_type = st.selectbox("Type*", ["general_liability", "directors_officers", "property", "cyber", "professional", "health", "life", "other"])
        provider = st.text_input("Insurance Provider*")
        policy_number = st.text_input("Policy Number")
        coverage_amount = st.number_input("Coverage Amount", value=0.0, format="%.2f")
        premium = st.number_input("Annual Premium", value=0.0, format="%.2f")
        currency = st.text_input("Currency", value="USD")
        start_date = st.date_input("Start Date")
        expiry_date = st.date_input("Expiry Date")
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            if not provider:
                st.error("Provider is required.")
            else:
                cid = db.get_company_id(company)
                db.insert_insurance_policy(
                    company_id=cid,
                    policy_type=policy_type,
                    provider=provider,
                    policy_number=policy_number or None,
                    coverage_amount=coverage_amount if coverage_amount > 0 else None,
                    premium=premium if premium > 0 else None,
                    currency=currency or "USD",
                    start_date=str(start_date),
                    expiry_date=str(expiry_date),
                    notes=notes or None,
                )
                st.success(f"Added policy: {provider}")
                st.rerun()

    if policies:
        st.subheader("Delete Insurance Policy")
        with st.form("delete_insurance"):
            pol_options = {f"{p['company_name']} — {p['provider']} ({p['policy_type']}) (ID {p['id']})": p["id"] for p in policies}
            del_choice = st.selectbox("Select policy to delete", list(pol_options.keys()))
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_insurance_policy(pol_options[del_choice])
                st.success("Deleted insurance policy")
                st.rerun()


# --- Board Meetings ---


def board_meetings_page() -> None:
    st.title("Board Meetings")

    meetings = db.get_board_meetings()

    if meetings:
        table_data = []
        for m in meetings:
            table_data.append({
                "ID": m["id"],
                "Company": m["company_name"],
                "Type": m["meeting_type"],
                "Date": m["scheduled_date"],
                "Status": m["status"],
                "Notes": m["notes"] or "",
            })
        st.dataframe(table_data, use_container_width=True, hide_index=True)
    else:
        st.info("No board meetings yet.")

    companies = db.get_all_companies()
    company_names = [c["name"] for c in companies]

    st.subheader("Schedule Board Meeting")
    with st.form("add_board_meeting", clear_on_submit=True):
        company = st.selectbox("Company*", company_names)
        meeting_type = st.selectbox("Type", ["regular", "special", "annual", "extraordinary"])
        scheduled_date = st.date_input("Date*")
        status = st.selectbox("Status", ["scheduled", "completed", "cancelled"])
        notes = st.text_area("Notes")

        if st.form_submit_button("Add"):
            cid = db.get_company_id(company)
            db.insert_board_meeting(
                company_id=cid,
                scheduled_date=str(scheduled_date),
                meeting_type=meeting_type,
                status=status,
                notes=notes or None,
            )
            st.success(f"Scheduled {meeting_type} meeting")
            st.rerun()

    if meetings:
        st.subheader("Update Meeting Status")
        with st.form("update_meeting"):
            mtg_options = {f"{m['company_name']} — {m['meeting_type']} ({m['scheduled_date']})": m["id"] for m in meetings}
            mtg_choice = st.selectbox("Select meeting", list(mtg_options.keys()))
            new_status = st.selectbox("New Status", ["scheduled", "completed", "cancelled"])
            if st.form_submit_button("Update"):
                db.update_board_meeting(mtg_options[mtg_choice], status=new_status)
                st.success("Updated meeting status")
                st.rerun()

        st.subheader("Delete Board Meeting")
        with st.form("delete_meeting"):
            mtg_del_choice = st.selectbox("Select meeting to delete", list(mtg_options.keys()), key="mtg_del")
            confirm = st.checkbox("I confirm deletion")
            if st.form_submit_button("Delete") and confirm:
                db.delete_board_meeting(mtg_options[mtg_del_choice])
                st.success("Deleted board meeting")
                st.rerun()


# --- Route ---

if page == "Dashboard":
    dashboard_page()
elif page == "Companies":
    companies_page()
elif page == "Asset Holdings":
    asset_holdings_page()
elif page == "Bank Accounts":
    bank_accounts_page()
elif page == "Transactions":
    transactions_page()
elif page == "Liabilities":
    liabilities_page()
elif page == "Documents":
    documents_page()
elif page == "Tax Calendar":
    tax_calendar_page()
elif page == "Financials":
    financials_page()
elif page == "Service Providers":
    service_providers_page()
elif page == "Insurance":
    insurance_page()
elif page == "Board Meetings":
    board_meetings_page()
elif page == "Audit Log":
    audit_log_page()
elif page == "Settings":
    settings_page()
