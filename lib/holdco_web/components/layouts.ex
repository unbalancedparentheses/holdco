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
        <% accounting_paths = ~w(/accounts/chart /accounts/journal /accounts/reports /accounts/integrations /depreciation /segments /revaluation /budgets/variance /waterfall /consolidated /leases) %>
        <% accounting_active = Enum.any?(accounting_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% portfolio_paths = ~w(/holdings /transactions /bank-accounts /financials /risk/concentration /debt-maturity /cash-forecast /scenarios) %>
        <% portfolio_active = Enum.any?(portfolio_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% corp_paths = ~w(/governance /compliance /documents /tax-calendar /audit-log /calendar /contacts /projects) %>
        <% corp_active = Enum.any?(corp_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <% reports_paths = ~w(/reports /tax/capital-gains /kpis /aging /management-reports /compare) %>
        <% reports_active = Enum.any?(reports_paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) %>
        <div class="nav-links">
          <.link navigate={~p"/"} class={if cur == "/", do: "active"}>Overview</.link>
          <.link
            navigate={~p"/companies"}
            class={if String.starts_with?(cur, "/companies") or cur == "/org-chart", do: "active"}
          >
            Companies
          </.link>
          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if portfolio_active, do: "more-active"}"}>Portfolio &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/holdings"} class={if String.starts_with?(cur, "/holdings"), do: "active"}>
                Holdings
              </.link>
              <.link navigate={~p"/transactions"} class={if String.starts_with?(cur, "/transactions"), do: "active"}>
                Transactions
              </.link>
              <.link navigate={~p"/bank-accounts"} class={if String.starts_with?(cur, "/bank-accounts"), do: "active"}>
                Bank Accounts
              </.link>
              <.link navigate={~p"/financials"} class={if cur == "/financials", do: "active"}>
                Financials
              </.link>
              <.link navigate={~p"/scenarios"} class={if String.starts_with?(cur, "/scenarios"), do: "active"}>
                Scenarios
              </.link>
              <.link navigate={~p"/risk/concentration"} class={if cur == "/risk/concentration", do: "active"}>
                Concentration Risk
              </.link>
              <.link navigate={~p"/debt-maturity"} class={if cur == "/debt-maturity", do: "active"}>
                Debt Maturity
              </.link>
              <.link navigate={~p"/cash-forecast"} class={if cur == "/cash-forecast", do: "active"}>
                Cash Forecast
              </.link>
            </div>
          </div>
          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if corp_active, do: "more-active"}"}>Corporate &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/governance"} class={if cur == "/governance", do: "active"}>
                Governance
              </.link>
              <.link navigate={~p"/compliance"} class={if cur == "/compliance", do: "active"}>
                Compliance
              </.link>
              <.link navigate={~p"/tax-calendar"} class={if cur == "/tax-calendar", do: "active"}>
                Tax Calendar
              </.link>
              <.link navigate={~p"/documents"} class={if cur == "/documents", do: "active"}>
                Documents
              </.link>
              <.link navigate={~p"/calendar"} class={if cur == "/calendar", do: "active"}>
                Calendar
              </.link>
              <.link navigate={~p"/contacts"} class={if String.starts_with?(cur, "/contacts"), do: "active"}>
                Contacts
              </.link>
              <.link navigate={~p"/projects"} class={if String.starts_with?(cur, "/projects"), do: "active"}>
                Projects
              </.link>
              <.link navigate={~p"/audit-log"} class={if cur == "/audit-log", do: "active"}>
                Audit Log
              </.link>
            </div>
          </div>
          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if accounting_active, do: "more-active"}"}>Accounting &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/accounts/chart"} class={if cur == "/accounts/chart", do: "active"}>
                Chart of Accounts
              </.link>
              <.link navigate={~p"/accounts/journal"} class={if cur == "/accounts/journal", do: "active"}>
                Journal Entries
              </.link>
              <.link navigate={~p"/accounts/reports"} class={if cur == "/accounts/reports", do: "active"}>
                Accounting Reports
              </.link>
              <.link navigate={~p"/accounts/integrations"} class={if cur == "/accounts/integrations", do: "active"}>
                Integrations
              </.link>
              <.link navigate={~p"/depreciation"} class={if cur == "/depreciation", do: "active"}>
                Depreciation
              </.link>
              <.link navigate={~p"/segments"} class={if cur == "/segments", do: "active"}>
                Segments
              </.link>
              <.link navigate={~p"/revaluation"} class={if cur == "/revaluation", do: "active"}>
                Revaluation
              </.link>
              <.link navigate={~p"/budgets/variance"} class={if cur == "/budgets/variance", do: "active"}>
                Budget Variance
              </.link>
              <.link navigate={~p"/waterfall"} class={if cur == "/waterfall", do: "active"}>
                Waterfall
              </.link>
              <.link navigate={~p"/consolidated"} class={if cur == "/consolidated", do: "active"}>
                Consolidated
              </.link>
              <.link navigate={~p"/leases"} class={if cur == "/leases", do: "active"}>
                Leases
              </.link>
            </div>
          </div>
          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if reports_active, do: "more-active"}"}>Reports &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/reports"} class={if cur == "/reports", do: "active"}>
                Overview
              </.link>
              <.link navigate={~p"/tax/capital-gains"} class={if cur == "/tax/capital-gains", do: "active"}>
                Capital Gains
              </.link>
              <.link navigate={~p"/kpis"} class={if cur == "/kpis", do: "active"}>
                KPIs
              </.link>
              <.link navigate={~p"/aging"} class={if cur == "/aging", do: "active"}>
                Aging
              </.link>
              <.link navigate={~p"/management-reports"} class={if cur == "/management-reports", do: "active"}>
                Management Reports
              </.link>
              <.link navigate={~p"/compare"} class={if cur == "/compare", do: "active"}>
                Entity Comparison
              </.link>
            </div>
          </div>
          <.link navigate={~p"/settings"} class={if cur == "/settings", do: "active"}>
            Settings
          </.link>
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
          <.link
            navigate={~p"/ai-chat"}
            class={"nav-util-link #{if cur == "/ai-chat", do: "active"}"}
          >
            AI Chat
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
    """
  end

  # Root layout is embedded from the template file
  embed_templates "layouts/root*"
end
