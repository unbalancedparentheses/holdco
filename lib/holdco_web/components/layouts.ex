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
        phx-disconnected={JS.show(to: ".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={JS.hide(to: "#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong!"
        phx-disconnected={JS.show(to: ".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
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
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="masthead">
      <div class="masthead-inner">
        <span class="masthead-label">Portfolio Management</span>
        <span class="masthead-title">Holdco</span>
        <span class="masthead-date"><%= Calendar.strftime(Date.utc_today(), "%A, %-d %B %Y") %></span>
      </div>
    </div>
    <nav class="nav-bar">
      <div class="nav-inner">
        <.link navigate={~p"/"} class="nav-brand">Holdco</.link>
        <div class="nav-links">
          <.link navigate={~p"/"} class={if @current_path == "/", do: "active"}>Overview</.link>
          <.link navigate={~p"/companies"} class={if String.starts_with?(@current_path || "", "/companies"), do: "active"}>Companies</.link>
          <.link navigate={~p"/holdings"} class={if @current_path == "/holdings", do: "active"}>Holdings</.link>
          <.link navigate={~p"/transactions"} class={if @current_path == "/transactions", do: "active"}>Transactions</.link>
          <.link navigate={~p"/bank-accounts"} class={if @current_path == "/bank-accounts", do: "active"}>Accounts</.link>
          <.link navigate={~p"/documents"} class={if @current_path == "/documents", do: "active"}>Documents</.link>
          <.link navigate={~p"/tax-calendar"} class={if @current_path == "/tax-calendar", do: "active"}>Tax</.link>
          <.link navigate={~p"/governance"} class={if @current_path == "/governance", do: "active"}>Governance</.link>
          <.link navigate={~p"/compliance"} class={if @current_path == "/compliance", do: "active"}>Compliance</.link>
          <.link navigate={~p"/financials"} class={if @current_path == "/financials", do: "active"}>Financials</.link>
          <.link navigate={~p"/scenarios"} class={if String.starts_with?(@current_path || "", "/scenarios"), do: "active"}>Scenarios</.link>
          <.link navigate={~p"/settings"} class={if @current_path == "/settings", do: "active"}>Settings</.link>
          <%= if @current_scope do %>
            <div class="nav-user">
              <span>{@current_scope.user.email}</span>
              <.link href={~p"/users/log-out"} method="delete">Logout</.link>
            </div>
          <% end %>
        </div>
      </div>
    </nav>

    <main class="page">
      <.flash_group flash={@flash} />
      {render_slot(@inner_block)}
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
    """
  end

  # Root layout is embedded from the template file
  embed_templates "layouts/root*"
end
