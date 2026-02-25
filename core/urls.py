from django.urls import path

from core import views

urlpatterns = [
    # Current user
    path("me", views.current_user_role),

    # Companies
    path("companies", views.company_list),
    path("companies/<int:company_id>", views.company_detail),

    # Asset Holdings
    path("holdings", views.holding_list),
    path("holdings/<int:holding_id>", views.holding_delete),

    # Custodians
    path("custodians", views.custodian_create),
    path("custodians/<int:custodian_id>", views.custodian_delete),

    # Documents
    path("documents", views.document_list),
    path("documents/<int:doc_id>", views.document_delete),

    # Tax Deadlines
    path("tax-deadlines", views.tax_deadline_list),
    path("tax-deadlines/<int:deadline_id>", views.tax_deadline_delete),

    # Financials
    path("financials", views.financial_list),
    path("financials/<int:financial_id>", views.financial_delete),

    # Categories
    path("categories", views.category_list),
    path("categories/<int:category_id>", views.category_delete),

    # Settings
    path("settings", views.settings_list),
    path("settings/<str:key>", views.setting_update),

    # Bank Accounts
    path("bank-accounts", views.bank_account_list),
    path("bank-accounts/<int:account_id>", views.bank_account_delete),

    # Transactions
    path("transactions", views.transaction_list),
    path("transactions/<int:transaction_id>", views.transaction_delete),

    # Liabilities
    path("liabilities", views.liability_list),
    path("liabilities/<int:liability_id>", views.liability_delete),

    # Service Providers
    path("service-providers", views.service_provider_list),
    path("service-providers/<int:provider_id>", views.service_provider_delete),

    # Insurance Policies
    path("insurance-policies", views.insurance_policy_list),
    path("insurance-policies/<int:policy_id>", views.insurance_policy_delete),

    # Board Meetings
    path("board-meetings", views.board_meeting_list),
    path("board-meetings/<int:meeting_id>", views.board_meeting_delete),

    # Prices
    path("prices/<str:ticker>", views.price_ticker),

    # Portfolio
    path("portfolio", views.portfolio_view),

    # Audit & Stats & Export
    path("audit-log", views.audit_log_list),
    path("audit-log/stream", views.audit_log_stream),
    path("stats", views.stats_view),
    path("export", views.export_view),
    path("entities", views.entities_view),

    # --- Corporate Structure & Governance ---
    path("cap-table", views.cap_table_list),
    path("cap-table/<int:entry_id>", views.cap_table_delete),
    path("shareholder-resolutions", views.shareholder_resolution_list),
    path("shareholder-resolutions/<int:resolution_id>", views.shareholder_resolution_delete),
    path("powers-of-attorney", views.power_of_attorney_list),
    path("powers-of-attorney/<int:poa_id>", views.power_of_attorney_delete),
    path("annual-filings", views.annual_filing_list),
    path("annual-filings/<int:filing_id>", views.annual_filing_delete),
    path("beneficial-owners", views.beneficial_owner_list),
    path("beneficial-owners/<int:owner_id>", views.beneficial_owner_delete),
    path("ownership-changes", views.ownership_change_list),
    path("ownership-changes/<int:change_id>", views.ownership_change_delete),
    path("key-personnel", views.key_personnel_list),
    path("key-personnel/<int:personnel_id>", views.key_personnel_delete),
    path("regulatory-licenses", views.regulatory_license_list),
    path("regulatory-licenses/<int:license_id>", views.regulatory_license_delete),
    path("joint-ventures", views.joint_venture_list),
    path("joint-ventures/<int:venture_id>", views.joint_venture_delete),
    path("equity-plans", views.equity_plan_list),
    path("equity-plans/<int:plan_id>", views.equity_plan_delete),
    path("equity-grants", views.equity_grant_list),
    path("equity-grants/<int:grant_id>", views.equity_grant_delete),
    path("deals", views.deal_list),
    path("deals/<int:deal_id>", views.deal_delete),

    # --- Financial Operations ---
    path("accounts", views.account_list),
    path("accounts/<int:account_id>", views.account_delete),
    path("journal-entries", views.journal_entry_list),
    path("journal-entries/<int:entry_id>", views.journal_entry_delete),
    path("journal-lines", views.journal_line_list),
    path("journal-lines/<int:line_id>", views.journal_line_delete),
    path("intercompany-transfers", views.intercompany_transfer_list),
    path("intercompany-transfers/<int:transfer_id>", views.intercompany_transfer_delete),
    path("dividends", views.dividend_list),
    path("dividends/<int:dividend_id>", views.dividend_delete),
    path("capital-contributions", views.capital_contribution_list),
    path("capital-contributions/<int:contribution_id>", views.capital_contribution_delete),
    path("tax-payments", views.tax_payment_list),
    path("tax-payments/<int:payment_id>", views.tax_payment_delete),
    path("budgets", views.budget_list),
    path("budgets/<int:budget_id>", views.budget_delete),

    # --- Asset Management ---
    path("cost-basis-lots", views.cost_basis_lot_list),
    path("cost-basis-lots/<int:lot_id>", views.cost_basis_lot_delete),
    path("real-estate", views.real_estate_property_list),
    path("real-estate/<int:property_id>", views.real_estate_property_delete),
    path("fund-investments", views.fund_investment_list),
    path("fund-investments/<int:investment_id>", views.fund_investment_delete),
    path("crypto-wallets", views.crypto_wallet_list),
    path("crypto-wallets/<int:wallet_id>", views.crypto_wallet_delete),

    # --- Tax & Compliance ---
    path("transfer-pricing", views.transfer_pricing_list),
    path("transfer-pricing/<int:doc_id>", views.transfer_pricing_delete),
    path("withholding-taxes", views.withholding_tax_list),
    path("withholding-taxes/<int:tax_id>", views.withholding_tax_delete),
    path("fatca-reports", views.fatca_report_list),
    path("fatca-reports/<int:report_id>", views.fatca_report_delete),
    path("esg-scores", views.esg_score_list),
    path("esg-scores/<int:score_id>", views.esg_score_delete),
    path("regulatory-filings", views.regulatory_filing_list),
    path("regulatory-filings/<int:filing_id>", views.regulatory_filing_delete),
    path("compliance-checklists", views.compliance_checklist_list),
    path("compliance-checklists/<int:checklist_id>", views.compliance_checklist_delete),

    # --- Documents ---
    path("document-versions", views.document_version_list),
    path("document-versions/<int:version_id>", views.document_version_delete),

    # --- Platform ---
    path("webhooks", views.webhook_list),
    path("webhooks/<int:webhook_id>", views.webhook_delete),
    path("approval-requests", views.approval_request_list),
    path("approval-requests/<int:request_id>", views.approval_request_delete),
    path("custom-fields", views.custom_field_list),
    path("custom-fields/<int:field_id>", views.custom_field_delete),
    path("custom-field-values", views.custom_field_value_list),
    path("custom-field-values/<int:value_id>", views.custom_field_value_delete),
    path("api-keys", views.api_key_list),
    path("api-keys/<int:key_id>", views.api_key_delete),
    path("entity-permissions", views.entity_permission_list),
    path("entity-permissions/<int:permission_id>", views.entity_permission_delete),

    # --- Disaster Recovery ---
    path("backup-configs", views.backup_config_list),
    path("backup-configs/<int:config_id>", views.backup_config_delete),
    path("backup-logs", views.backup_log_list),
    path("backup-logs/<int:log_id>", views.backup_log_delete),

    # --- Computed Endpoints ---
    path("search", views.search_view),
    path("export/csv", views.csv_export),
    path("gains", views.gains_view),
    path("asset-allocation", views.asset_allocation_view),
    path("fx-exposure", views.fx_exposure_view),
    path("cash-flow", views.cash_flow_view),
    path("consolidated", views.consolidated_view),
    path("contract-alerts", views.contract_alerts_view),
    path("ownership-diagram", views.ownership_diagram_view),
    path("benchmarks", views.benchmark_view),
    path("bulk-update", views.bulk_update_view),

    # --- Multi-tenant ---
    path("tenant-groups", views.tenant_group_list),
    path("tenant-groups/<int:group_id>", views.tenant_group_delete),
    path("tenant-memberships", views.tenant_membership_list),
    path("tenant-memberships/<int:membership_id>", views.tenant_membership_delete),

    # --- Treasury ---
    path("cash-pools", views.cash_pool_list),
    path("cash-pools/<int:pool_id>", views.cash_pool_delete),
    path("cash-pool-entries", views.cash_pool_entry_list),
    path("cash-pool-entries/<int:entry_id>", views.cash_pool_entry_delete),

    # --- Sanctions ---
    path("sanctions-lists", views.sanctions_list_view),
    path("sanctions-lists/<int:list_id>", views.sanctions_list_delete_view),
    path("sanctions-entries", views.sanctions_entry_list),
    path("sanctions-entries/<int:entry_id>", views.sanctions_entry_delete),
    path("sanctions-checks", views.sanctions_check_list),
    path("sanctions-checks/<int:check_id>", views.sanctions_check_delete),

    # --- Portfolio Snapshots ---
    path("portfolio-snapshots", views.portfolio_snapshot_list),
    path("portfolio-snapshots/<int:snapshot_id>", views.portfolio_snapshot_delete),

    # --- Accounting Sync ---
    path("accounting-sync-configs", views.accounting_sync_config_list),
    path("accounting-sync-configs/<int:config_id>", views.accounting_sync_config_delete),
    path("accounting-sync-logs", views.accounting_sync_log_list),
    path("accounting-sync-logs/<int:log_id>", views.accounting_sync_log_delete),

    # --- Bank Feed ---
    path("bank-feed-configs", views.bank_feed_config_list),
    path("bank-feed-configs/<int:config_id>", views.bank_feed_config_delete),
    path("bank-feed-transactions", views.bank_feed_transaction_list),
    path("bank-feed-transactions/<int:txn_id>", views.bank_feed_transaction_delete),

    # --- E-Signature ---
    path("signature-requests", views.signature_request_list),
    path("signature-requests/<int:request_id>", views.signature_request_delete),

    # --- Email Digest ---
    path("email-digest-configs", views.email_digest_config_list),
    path("email-digest-configs/<int:config_id>", views.email_digest_config_delete),

    # --- Investor Portal ---
    path("investor-access", views.investor_access_list),
    path("investor-access/<int:access_id>", views.investor_access_delete),
    path("investor-portal", views.investor_portal_view),

    # --- Document Upload ---
    path("document-uploads", views.document_upload_list),
    path("document-uploads/<int:upload_id>", views.document_upload_delete),

    # --- Computed Endpoints (Wave 2) ---
    path("nlq", views.nlq_view),
    path("tax-loss-harvesting", views.tax_loss_harvesting_view),
    path("pnl-trends", views.pnl_trends_view),
    path("asset-allocation-chart", views.asset_allocation_chart_view),
    path("board-package.pdf", views.board_package_pdf_view),
    path("calendar.ics", views.ical_export_view),
    path("portfolio-performance", views.portfolio_performance_view),
]
