defmodule HoldcoWeb.Router do
  use HoldcoWeb, :router

  import HoldcoWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HoldcoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug HoldcoWeb.Plugs.ApiKeyAuth
  end

  # Health check (no auth)
  scope "/", HoldcoWeb do
    pipe_through [:api]
    get "/health", HealthController, :index
  end

  # JSON API (API key auth)
  scope "/api", HoldcoWeb.Api do
    pipe_through [:api_authenticated]

    get "/health", HealthController, :index
    get "/portfolio", PortfolioController, :index
    get "/portfolio/allocation", PortfolioController, :allocation
    get "/portfolio/fx-exposure", PortfolioController, :fx_exposure
    get "/companies", CompanyController, :index
    get "/companies/:id", CompanyController, :show
    get "/holdings", HoldingController, :index
    get "/transactions", TransactionController, :index
  end

  # CSV Exports (authenticated)
  scope "/export", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/companies.csv", ExportController, :companies
    get "/holdings.csv", ExportController, :holdings
    get "/transactions.csv", ExportController, :transactions
    get "/chart-of-accounts.csv", ExportController, :chart_of_accounts
    get "/journal-entries.csv", ExportController, :journal_entries
    get "/audit-log.csv", ExportController, :audit_log
    get "/audit-package.zip", ExportController, :audit_package
    get "/xbrl/:id", XbrlController, :export

    get "/tax-provisions.csv", TaxExportController, :tax_provisions_csv
    get "/deferred-taxes.csv", TaxExportController, :deferred_taxes_csv
    get "/withholding-reclaims.csv", TaxExportController, :withholding_reclaims_csv
    get "/k1-reports.csv", TaxExportController, :k1_reports_csv
    get "/tax-package.zip", TaxExportController, :tax_package_zip
  end

  # QuickBooks OAuth (authenticated)
  scope "/auth/quickbooks", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/connect", QuickbooksController, :connect
    get "/callback", QuickbooksController, :callback
  end

  # Xero OAuth (authenticated)
  scope "/auth/xero", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/connect", XeroController, :connect
    get "/callback", XeroController, :callback
  end

  # Printable Reports (authenticated)
  scope "/reports", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/portfolio", ReportController, :portfolio
    get "/financial", ReportController, :financial
    get "/compliance", ReportController, :compliance
  end

  # File downloads (authenticated)
  scope "/", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/downloads/:id", DownloadController, :show
    get "/downloads/:id/preview", DownloadController, :preview
  end

  # Plaid (authenticated)
  scope "/auth/plaid", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    post "/link-token", PlaidController, :create_link_token
    post "/exchange-token", PlaidController, :exchange_token
  end

  # Plaid webhooks (no auth - verified via webhook_verification)
  scope "/webhooks", HoldcoWeb do
    pipe_through [:api]

    post "/plaid", PlaidController, :webhook
  end

  # Public routes (no auth required)
  scope "/", HoldcoWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
    get "/users/totp-verify", TotpVerificationController, :new
    post "/users/totp-verify", TotpVerificationController, :create
  end

  scope "/", HoldcoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  # Authenticated non-live routes (user settings, etc.)
  scope "/", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  # Authenticated LiveView routes
  scope "/", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      layout: {HoldcoWeb.Layouts, :app},
      on_mount: [
        {HoldcoWeb.UserAuth, :ensure_authenticated},
        {HoldcoWeb.Live.Hooks, :current_path}
      ] do
      live "/", DashboardLive, :index
      live "/companies", CompanyLive.Index, :index
      live "/companies/new", CompanyLive.Index, :new
      live "/companies/:id", CompanyLive.Show, :show
      live "/companies/:id/edit", CompanyLive.Show, :edit
      live "/holdings", HoldingsLive.Index, :index
      live "/holdings/:id", HoldingsLive.Show, :show
      live "/transactions", TransactionsLive.Index, :index
      live "/transactions/:id", TransactionsLive.Show, :show
      live "/bank-accounts", BankAccountsLive.Index, :index
      live "/bank-accounts/:id", BankAccountsLive.Show, :show
      live "/documents", DocumentsLive.Index, :index
      live "/calendar", CalendarLive.Index, :index
      live "/tax-calendar", TaxCalendarLive.Index, :index
      live "/financials", FinancialsLive.Index, :index
      live "/accounts/chart", AccountingLive.ChartOfAccounts, :index
      live "/accounts/journal", AccountingLive.Journal, :index
      live "/accounts/reports", AccountingLive.Reports, :index
      live "/accounts/integrations", AccountingLive.Integrations, :index
      live "/approvals", ApprovalsLive.Index, :index
      live "/import", ImportLive, :index
      live "/notifications", NotificationsLive, :index
      live "/settings/notifications", NotificationSettingsLive.Index, :index
      live "/search", SearchLive, :index
      live "/contacts", ContactLive.Index, :index
      live "/audit-log", AuditLive.Index, :index
      live "/reports", ReportsLive, :index
      live "/settings", SettingsLive.Index, :index
      live "/users/settings/2fa", TotpSetupLive, :index

      # Phase 1 — Portfolio & Risk
      live "/risk/concentration", ConcentrationRiskLive.Index, :index
      live "/debt-maturity", DebtMaturityLive.Index, :index
      live "/cash-forecast", CashForecastLive.Index, :index

      # Phase 1 — Corporate
      live "/org-chart", OrgChartLive.Index, :index

      # Phase 1 — Accounting & Finance
      live "/budgets/variance", BudgetVarianceLive.Index, :index
      live "/consolidated", ConsolidatedLive.Index, :index
      live "/compare", EntityComparisonLive.Index, :index


      # Phase 1 — Reports & Analytics
      live "/tax/capital-gains", CapitalGainsLive.Index, :index

      # Phase 2 — Period Close & Recurring
      live "/period-locks", PeriodLockLive.Index, :index
      live "/recurring-transactions", RecurringTransactionsLive.Index, :index

      # Phase 2 — Bank Reconciliation
      live "/bank-reconciliation", BankReconciliationLive.Index, :index

      # Phase 2 — Scheduled Reports
      live "/scheduled-reports", ScheduledReportsLive.Index, :index

      # Phase 2 — Alerts
      live "/alerts", AlertsLive.Index, :index

      # Phase 2 — Stress Testing
      live "/stress-test", StressTestLive.Index, :index

      # Phase 2 — Anomaly Detection
      live "/anomalies", AnomalyLive.Index, :index

      # Tax
      live "/tax-provisions", TaxProvisionLive.Index, :index
      live "/deferred-taxes", DeferredTaxLive.Index, :index
      live "/transfer-pricing", TransferPricingLive.Index, :index


      # Contracts
      live "/contracts", ContractLive.Index, :index

    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:holdco, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HoldcoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
