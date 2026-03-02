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
        <% active? = fn paths -> Enum.any?(paths, fn p -> cur == p or String.starts_with?(cur, p <> "/") end) end %>
        <% portfolio_paths = ~w(/holdings /transactions /bank-accounts /financials) %>
        <% corp_paths = ~w(/documents /contacts /calendar /org-chart /contracts) %>
        <% accounting_paths = ~w(/accounts/chart /accounts/journal /accounts/reports /accounts/integrations /budgets/variance /consolidated /period-locks /recurring-transactions /bank-reconciliation) %>
        <% tax_paths = ~w(/tax-provisions /deferred-taxes /transfer-pricing /tax/capital-gains /tax-calendar) %>
        <% risk_paths = ~w(/risk/concentration /debt-maturity /cash-forecast /stress-test /anomalies) %>
        <% reports_paths = ~w(/reports /compare /scheduled-reports) %>
        <% admin_paths = ~w(/settings /settings/notifications /audit-log /alerts /approvals /notifications /import) %>
        <div class="nav-links">
          <.link navigate={~p"/"} class={if cur == "/", do: "active"}>Overview</.link>
          <.link navigate={~p"/companies"} class={if String.starts_with?(cur, "/companies"), do: "active"}>Companies</.link>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(portfolio_paths), do: "more-active"}"}>Portfolio &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/holdings"} class={if String.starts_with?(cur, "/holdings"), do: "active"}>Positions</.link>
              <.link navigate={~p"/transactions"} class={if String.starts_with?(cur, "/transactions"), do: "active"}>Transactions</.link>
              <.link navigate={~p"/bank-accounts"} class={if String.starts_with?(cur, "/bank-accounts"), do: "active"}>Bank Accounts</.link>
              <.link navigate={~p"/financials"} class={if cur == "/financials", do: "active"}>Financials</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(corp_paths), do: "more-active"}"}>Corporate &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/documents"} class={if cur == "/documents", do: "active"}>Documents</.link>
              <.link navigate={~p"/contacts"} class={if String.starts_with?(cur, "/contacts"), do: "active"}>Contacts</.link>
              <.link navigate={~p"/calendar"} class={if cur == "/calendar", do: "active"}>Calendar</.link>
              <.link navigate={~p"/org-chart"} class={if cur == "/org-chart", do: "active"}>Org Chart</.link>
              <.link navigate={~p"/contracts"} class={if cur == "/contracts", do: "active"}>Contracts</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(accounting_paths), do: "more-active"}"}>Accounting &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/accounts/chart"} class={if cur == "/accounts/chart", do: "active"}>Chart of Accounts</.link>
              <.link navigate={~p"/accounts/journal"} class={if cur == "/accounts/journal", do: "active"}>Journal Entries</.link>
              <.link navigate={~p"/accounts/reports"} class={if cur == "/accounts/reports", do: "active"}>Reports</.link>
              <.link navigate={~p"/accounts/integrations"} class={if cur == "/accounts/integrations", do: "active"}>Integrations</.link>
              <.link navigate={~p"/consolidated"} class={if cur == "/consolidated", do: "active"}>Consolidated</.link>
              <.link navigate={~p"/period-locks"} class={if cur == "/period-locks", do: "active"}>Period Locks</.link>
              <.link navigate={~p"/recurring-transactions"} class={if cur == "/recurring-transactions", do: "active"}>Recurring</.link>
              <.link navigate={~p"/bank-reconciliation"} class={if cur == "/bank-reconciliation", do: "active"}>Reconciliation</.link>
              <.link navigate={~p"/budgets/variance"} class={if cur == "/budgets/variance", do: "active"}>Budget Variance</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(tax_paths), do: "more-active"}"}>Tax &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/tax-provisions"} class={if cur == "/tax-provisions", do: "active"}>Tax Provisions</.link>
              <.link navigate={~p"/deferred-taxes"} class={if cur == "/deferred-taxes", do: "active"}>Deferred Taxes</.link>
              <.link navigate={~p"/transfer-pricing"} class={if cur == "/transfer-pricing", do: "active"}>Transfer Pricing</.link>
              <.link navigate={~p"/tax/capital-gains"} class={if cur == "/tax/capital-gains", do: "active"}>Capital Gains</.link>
              <.link navigate={~p"/tax-calendar"} class={if cur == "/tax-calendar", do: "active"}>Tax Calendar</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(risk_paths), do: "more-active"}"}>Risk &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/risk/concentration"} class={if cur == "/risk/concentration", do: "active"}>Concentration</.link>
              <.link navigate={~p"/stress-test"} class={if cur == "/stress-test", do: "active"}>Stress Testing</.link>
              <.link navigate={~p"/debt-maturity"} class={if cur == "/debt-maturity", do: "active"}>Debt Maturity</.link>
              <.link navigate={~p"/cash-forecast"} class={if cur == "/cash-forecast", do: "active"}>Cash Forecast</.link>
              <.link navigate={~p"/anomalies"} class={if cur == "/anomalies", do: "active"}>Anomalies</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(reports_paths), do: "more-active"}"}>Reports &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/reports"} class={if cur == "/reports", do: "active"}>Overview</.link>
              <.link navigate={~p"/compare"} class={if cur == "/compare", do: "active"}>Entity Comparison</.link>
              <.link navigate={~p"/scheduled-reports"} class={if cur == "/scheduled-reports", do: "active"}>Scheduled Reports</.link>
            </div>
          </div>

          <div class="nav-dropdown">
            <button class={"nav-dropdown-toggle #{if active?.(admin_paths), do: "more-active"}"}>Admin &#9662;</button>
            <div class="nav-dropdown-menu">
              <.link navigate={~p"/settings"} class={if cur == "/settings", do: "active"}>Settings</.link>
              <.link navigate={~p"/settings/notifications"} class={if cur == "/settings/notifications", do: "active"}>Notification Settings</.link>
              <.link navigate={~p"/audit-log"} class={if cur == "/audit-log", do: "active"}>Audit Log</.link>
              <.link navigate={~p"/approvals"} class={if cur == "/approvals", do: "active"}>Approvals</.link>
              <.link navigate={~p"/notifications"} class={if cur == "/notifications", do: "active"}>Notifications</.link>
              <.link navigate={~p"/alerts"} class={if cur == "/alerts", do: "active"}>Alerts</.link>
              <.link navigate={~p"/import"} class={if cur == "/import", do: "active"}>Import</.link>
            </div>
          </div>
        </div>
        <div class="nav-utils">
          <% pending_count = Holdco.Platform.pending_approval_count() %>
          <.link
            navigate={~p"/approvals"}
            class={"nav-util-link #{if cur == "/approvals", do: "active"}"}
          >
            Approvals<%= if pending_count > 0, do: " (#{pending_count})" %>
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
