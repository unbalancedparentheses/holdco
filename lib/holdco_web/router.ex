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
  end

  # QuickBooks OAuth (authenticated)
  scope "/auth/quickbooks", HoldcoWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/connect", QuickbooksController, :connect
    get "/callback", QuickbooksController, :callback
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
      live "/tax-calendar", TaxCalendarLive.Index, :index
      live "/financials", FinancialsLive.Index, :index
      live "/accounts/chart", AccountingLive.ChartOfAccounts, :index
      live "/accounts/journal", AccountingLive.Journal, :index
      live "/accounts/reports", AccountingLive.Reports, :index
      live "/accounts/integrations", AccountingLive.Integrations, :index
      live "/governance", GovernanceLive.Index, :index
      live "/compliance", ComplianceLive.Index, :index
      live "/approvals", ApprovalsLive.Index, :index
      live "/scenarios", ScenarioLive.Index, :index
      live "/scenarios/new", ScenarioLive.Index, :new
      live "/scenarios/:id", ScenarioLive.Show, :show
      live "/import", ImportLive, :index
      live "/notifications", NotificationsLive, :index
      live "/search", SearchLive, :index
      live "/contacts", ContactLive.Index, :index
      live "/projects", ProjectLive.Index, :index
      live "/audit-log", AuditLive.Index, :index
      live "/reports", ReportsLive, :index
      live "/settings", SettingsLive.Index, :index
      live "/users/settings/2fa", TotpSetupLive, :index
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
