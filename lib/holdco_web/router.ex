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

  # Public routes (no auth required)
  scope "/", HoldcoWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
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
      live "/transactions", TransactionsLive.Index, :index
      live "/bank-accounts", BankAccountsLive.Index, :index
      live "/documents", DocumentsLive.Index, :index
      live "/tax-calendar", TaxCalendarLive.Index, :index
      live "/financials", FinancialsLive.Index, :index
      live "/governance", GovernanceLive.Index, :index
      live "/compliance", ComplianceLive.Index, :index
      live "/scenarios", ScenarioLive.Index, :index
      live "/scenarios/new", ScenarioLive.Index, :new
      live "/scenarios/:id", ScenarioLive.Show, :show
      live "/audit-log", AuditLive.Index, :index
      live "/settings", SettingsLive.Index, :index
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
