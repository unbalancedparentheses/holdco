defmodule HoldcoWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HoldcoWeb, :html

  alias Phoenix.LiveView.JS

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="We can't find the internet"
        phx-disconnected={
          JS.show(to: ".phx-client-error #client-error") |> JS.remove_attribute("hidden")
        }
        phx-connected={JS.hide(to: "#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={
          JS.show(to: ".phx-server-error #server-error") |> JS.remove_attribute("hidden")
        }
        phx-connected={JS.hide(to: "#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
      </.flash>
    </div>
    """
  end

  @doc """
  Renders the app layout (masthead, nav, content, footer).
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  slot :inner_block

  def app(%{current_scope: nil} = assigns) do
    ~H"""
    <div class="auth-page">
      <div class="auth-page-inner">
        <div class="auth-brand">
          <span class="auth-brand-name">Holdco</span>
          <span class="auth-brand-tagline">Holding company management</span>
        </div>
        <.flash_group flash={@flash} />
        <%= if assigns[:inner_content] do %>
          {@inner_content}
        <% else %>
          {render_slot(@inner_block)}
        <% end %>
      </div>
    </div>
    """
  end

  def app(assigns) do
    ~H"""
    <div class="masthead">
      <div class="masthead-inner">
        <span class="masthead-label">Portfolio Management</span>
        <span class="masthead-title">Holdco</span>
        <span class="masthead-date">{Calendar.strftime(Date.utc_today(), "%A, %-d %B %Y")}</span>
      </div>
    </div>
    <nav class="nav-bar">
      <div class="nav-inner">
        <.link navigate={~p"/"} class="nav-brand">Holdco</.link>
        <% cur = @current_path || "" %>
        <% portfolio_paths = ~w(/holdings /transactions /bank-accounts /financials /scenarios /defi-positions) %>
        <% portfolio_active = Enum.any?(portfolio_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% fund_paths = ~w(/capital-calls /distributions /waterfall /k1-reports /fund-nav /investor-statements /fund-fees /dividend-policies /fundraising /partnership-basis) %>
        <% fund_active = Enum.any?(fund_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% corp_paths = ~w(/governance /compliance /documents /entity-lifecycle /registers /corporate-actions /board-meetings /contracts /kyc /share-classes /contacts /calendar /audit-log) %>
        <% corp_active = Enum.any?(corp_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% accounting_paths = ~w(/accounts/chart /accounts/journal /accounts/reports /accounts/integrations /depreciation /segments /revaluation /budgets/variance /waterfall /consolidated /leases /period-locks /recurring-transactions /bank-reconciliation /multi-book) %>
        <% accounting_active = Enum.any?(accounting_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% tax_paths = ~w(/tax-provisions /deferred-taxes /tax-optimizer /withholding-reclaims /repatriation /transfer-pricing /tax/capital-gains /tax-calendar) %>
        <% tax_active = Enum.any?(tax_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% risk_paths = ~w(/risk/concentration /debt-maturity /cash-forecast /counterparty-risk /covenants /stress-test /liquidity /anomalies /benchmarks /esg /regulatory-capital) %>
        <% risk_active = Enum.any?(risk_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% reports_paths = ~w(/reports /kpis /aging /management-reports /audit-diffs /compare /scheduled-reports) %>
        <% reports_active = Enum.any?(reports_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <div class="nav-links">
          <.link navigate={~p"/"} class={if cur == "/", do: "active"}>Overview</.link>
          <.link navigate={~p"/companies"} class={if String.starts_with?(cur, "/companies"), do: "active"}>Companies</.link>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if portfolio_active, do: "more-active"}"}>Portfolio &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/holdings"} class={if String.starts_with?(cur, "/holdings"), do: "active"}>Positions</.link>
              <.link navigate={~p"/transactions"} class={if String.starts_with?(cur, "/transactions"), do: "active"}>Transactions</.link>
              <.link navigate={~p"/bank-accounts"} class={if String.starts_with?(cur, "/bank-accounts"), do: "active"}>Bank Accounts</.link>
              <.link navigate={~p"/financials"} class={if cur == "/financials", do: "active"}>Financials</.link>
              <.link navigate={~p"/scenarios"} class={if String.starts_with?(cur, "/scenarios"), do: "active"}>Scenarios</.link>
              <.link navigate={~p"/defi-positions"} class={if cur == "/defi-positions", do: "active"}>DeFi Positions</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if fund_active, do: "more-active"}"}>Fund &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/capital-calls"} class={if cur == "/capital-calls", do: "active"}>Capital Calls</.link>
              <.link navigate={~p"/distributions"} class={if cur == "/distributions", do: "active"}>Distributions</.link>
              <.link navigate={~p"/fund-nav"} class={if cur == "/fund-nav", do: "active"}>Fund NAV</.link>
              <.link navigate={~p"/investor-statements"} class={if cur == "/investor-statements", do: "active"}>Investor Statements</.link>
              <.link navigate={~p"/fund-fees"} class={if cur == "/fund-fees", do: "active"}>Fees</.link>
              <.link navigate={~p"/k1-reports"} class={if cur == "/k1-reports", do: "active"}>K-1 Reports</.link>
              <.link navigate={~p"/dividend-policies"} class={if cur == "/dividend-policies", do: "active"}>Dividend Policies</.link>
              <.link navigate={~p"/fundraising"} class={if cur == "/fundraising", do: "active"}>Fundraising</.link>
              <.link navigate={~p"/partnership-basis"} class={if cur == "/partnership-basis", do: "active"}>Partnership Basis</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if corp_active, do: "more-active"}"}>Corporate &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/governance"} class={if cur == "/governance", do: "active"}>Governance</.link>
              <.link navigate={~p"/compliance"} class={if cur == "/compliance", do: "active"}>Compliance</.link>
              <.link navigate={~p"/documents"} class={if cur == "/documents", do: "active"}>Documents</.link>
              <.link navigate={~p"/board-meetings"} class={if cur == "/board-meetings", do: "active"}>Board Meetings</.link>
              <.link navigate={~p"/corporate-actions"} class={if cur == "/corporate-actions", do: "active"}>Corporate Actions</.link>
              <.link navigate={~p"/entity-lifecycle"} class={if cur == "/entity-lifecycle", do: "active"}>Entity Lifecycle</.link>
              <.link navigate={~p"/registers"} class={if cur == "/registers", do: "active"}>Registers</.link>
              <.link navigate={~p"/contracts"} class={if cur == "/contracts", do: "active"}>Contracts</.link>
              <.link navigate={~p"/kyc"} class={if cur == "/kyc", do: "active"}>KYC/AML</.link>
              <.link navigate={~p"/share-classes"} class={if cur == "/share-classes", do: "active"}>Share Classes</.link>
              <.link navigate={~p"/contacts"} class={if String.starts_with?(cur, "/contacts"), do: "active"}>Contacts</.link>
              <.link navigate={~p"/audit-log"} class={if cur == "/audit-log", do: "active"}>Audit Log</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if accounting_active, do: "more-active"}"}>Accounting &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/accounts/chart"} class={if cur == "/accounts/chart", do: "active"}>Chart of Accounts</.link>
              <.link navigate={~p"/accounts/journal"} class={if cur == "/accounts/journal", do: "active"}>Journal Entries</.link>
              <.link navigate={~p"/accounts/reports"} class={if cur == "/accounts/reports", do: "active"}>Reports</.link>
              <.link navigate={~p"/accounts/integrations"} class={if cur == "/accounts/integrations", do: "active"}>Integrations</.link>
              <.link navigate={~p"/depreciation"} class={if cur == "/depreciation", do: "active"}>Depreciation</.link>
              <.link navigate={~p"/revaluation"} class={if cur == "/revaluation", do: "active"}>Revaluation</.link>
              <.link navigate={~p"/segments"} class={if cur == "/segments", do: "active"}>Segments</.link>
              <.link navigate={~p"/consolidated"} class={if cur == "/consolidated", do: "active"}>Consolidated</.link>
              <.link navigate={~p"/multi-book"} class={if cur == "/multi-book", do: "active"}>Multi-Book</.link>
              <.link navigate={~p"/period-locks"} class={if cur == "/period-locks", do: "active"}>Period Locks</.link>
              <.link navigate={~p"/recurring-transactions"} class={if cur == "/recurring-transactions", do: "active"}>Recurring</.link>
              <.link navigate={~p"/bank-reconciliation"} class={if cur == "/bank-reconciliation", do: "active"}>Reconciliation</.link>
              <.link navigate={~p"/budgets/variance"} class={if cur == "/budgets/variance", do: "active"}>Budget Variance</.link>
              <.link navigate={~p"/waterfall"} class={if cur == "/waterfall", do: "active"}>Waterfall</.link>
              <.link navigate={~p"/leases"} class={if cur == "/leases", do: "active"}>Leases</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if tax_active, do: "more-active"}"}>Tax &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/tax-provisions"} class={if cur == "/tax-provisions", do: "active"}>Tax Provisions</.link>
              <.link navigate={~p"/deferred-taxes"} class={if cur == "/deferred-taxes", do: "active"}>Deferred Taxes</.link>
              <.link navigate={~p"/tax-optimizer"} class={if cur == "/tax-optimizer", do: "active"}>Tax Optimizer</.link>
              <.link navigate={~p"/withholding-reclaims"} class={if cur == "/withholding-reclaims", do: "active"}>Withholding Reclaims</.link>
              <.link navigate={~p"/repatriation"} class={if cur == "/repatriation", do: "active"}>Repatriation</.link>
              <.link navigate={~p"/transfer-pricing"} class={if cur == "/transfer-pricing", do: "active"}>Transfer Pricing</.link>
              <.link navigate={~p"/tax/capital-gains"} class={if cur == "/tax/capital-gains", do: "active"}>Capital Gains</.link>
              <.link navigate={~p"/tax-calendar"} class={if cur == "/tax-calendar", do: "active"}>Tax Calendar</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if risk_active, do: "more-active"}"}>Risk &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/risk/concentration"} class={if cur == "/risk/concentration", do: "active"}>Concentration</.link>
              <.link navigate={~p"/counterparty-risk"} class={if cur == "/counterparty-risk", do: "active"}>Counterparty</.link>
              <.link navigate={~p"/covenants"} class={if cur == "/covenants", do: "active"}>Covenants</.link>
              <.link navigate={~p"/stress-test"} class={if cur == "/stress-test", do: "active"}>Stress Testing</.link>
              <.link navigate={~p"/liquidity"} class={if cur == "/liquidity", do: "active"}>Liquidity</.link>
              <.link navigate={~p"/debt-maturity"} class={if cur == "/debt-maturity", do: "active"}>Debt Maturity</.link>
              <.link navigate={~p"/cash-forecast"} class={if cur == "/cash-forecast", do: "active"}>Cash Forecast</.link>
              <.link navigate={~p"/esg"} class={if cur == "/esg", do: "active"}>ESG</.link>
              <.link navigate={~p"/regulatory-capital"} class={if cur == "/regulatory-capital", do: "active"}>Regulatory Capital</.link>
              <.link navigate={~p"/anomalies"} class={if cur == "/anomalies", do: "active"}>Anomalies</.link>
              <.link navigate={~p"/benchmarks"} class={if cur == "/benchmarks", do: "active"}>Benchmarks</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if reports_active, do: "more-active"}"}>Reports &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/reports"} class={if cur == "/reports", do: "active"}>Overview</.link>
              <.link navigate={~p"/kpis"} class={if cur == "/kpis", do: "active"}>KPIs</.link>
              <.link navigate={~p"/aging"} class={if cur == "/aging", do: "active"}>Aging</.link>
              <.link navigate={~p"/management-reports"} class={if cur == "/management-reports", do: "active"}>Management Reports</.link>
              <.link navigate={~p"/compare"} class={if cur == "/compare", do: "active"}>Entity Comparison</.link>
              <.link navigate={~p"/audit-diffs"} class={if cur == "/audit-diffs", do: "active"}>Audit Diffs</.link>
              <.link navigate={~p"/scheduled-reports"} class={if cur == "/scheduled-reports", do: "active"}>Scheduled Reports</.link>
            </div>
          </div>

          <.link navigate={~p"/settings"} class={if cur == "/settings", do: "active"}>Settings</.link>
        </div>
        <div class="nav-utils">
          <% pending_count = Holdco.Platform.pending_approval_count() %>
          <.link
            navigate={~p"/approvals"}
            class={"nav-util-link #{if cur == "/approvals", do: "active"}"}
          >
            Approvals<%= if pending_count > 0, do: " (#{pending_count})" %>
          </.link>
          <.link
            navigate={~p"/notifications"}
            class={"nav-util-link #{if cur == "/notifications", do: "active"}"}
          >
            Notifications
          </.link>
          <.link
            navigate={~p"/import"}
            class={"nav-util-link #{if cur == "/import", do: "active"}"}
          >
            Import
          </.link>
          <form class="nav-search" action={~p"/search"} method="get">
            <input type="text" name="q" placeholder="Search..." />
          </form>
          <div class="nav-user">
            <span>{@current_scope.user.email}</span>
            <.link href={~p"/users/log-out"} method="delete">Logout</.link>
          </div>
        </div>
      </div>
    </nav>

    <main class="page">
      <.flash_group flash={@flash} />
      <%= if assigns[:inner_content] do %>
        {@inner_content}
      <% else %>
        {render_slot(@inner_block)}
      <% end %>
    </main>

    <footer>
      <div class="page">
        <div class="footer">
          <span class="footer-text">Holdco — Open source holding company management</span>
          <div class="footer-links">
            <.link navigate={~p"/audit-log"}>Audit Log</.link>
            <.link navigate={~p"/audit-diffs"}>Audit Diffs</.link>
            <.link navigate={~p"/settings"}>Settings</.link>
          </div>
        </div>
      </div>
    </footer>

    <%= if @current_scope && assigns[:socket] do %>
      {live_render(@socket, HoldcoWeb.AiChatLive, id: "ai-chat-drawer", sticky: true)}
    <% end %>
    """
  end

  # Root layout is embedded from the template file
  embed_templates "layouts/root*"
end
