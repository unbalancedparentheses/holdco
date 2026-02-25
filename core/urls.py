from django.urls import path

from core import views

urlpatterns = [
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

    # Audit & Stats & Export
    path("audit-log", views.audit_log_list),
    path("stats", views.stats_view),
    path("export", views.export_view),
    path("entities", views.entities_view),
]
