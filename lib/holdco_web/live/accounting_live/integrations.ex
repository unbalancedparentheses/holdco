defmodule HoldcoWeb.AccountingLive.Integrations do
  use HoldcoWeb, :live_view

  alias Holdco.{Integrations, Corporate}
  alias Holdco.Integrations.Quickbooks

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Integrations.subscribe()

    qbo = Integrations.get_integration("quickbooks")
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Integrations",
       qbo: qbo,
       companies: companies,
       selected_company_id: "",
       syncing: false,
       sync_result: nil
     )}
  end

  @impl true
  def handle_event("disconnect", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("sync", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("disconnect", _params, socket) do
    case Integrations.disconnect_integration("quickbooks") do
      {:ok, _} ->
        {:noreply,
         assign(socket, qbo: nil, sync_result: nil)
         |> put_flash(:info, "QuickBooks disconnected")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect")}
    end
  end

  def handle_event("select_sync_company", %{"company_id" => id}, socket) do
    {:noreply, assign(socket, selected_company_id: id)}
  end

  def handle_event("sync", _params, socket) do
    send(self(), :do_sync)
    {:noreply, assign(socket, syncing: true, sync_result: nil)}
  end

  @impl true
  def handle_info(:do_sync, socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    result = Quickbooks.sync_all(company_id)

    sync_result =
      case result do
        {:ok, results} -> {:ok, results}
        {:error, reason} -> {:error, reason}
      end

    qbo = Integrations.get_integration("quickbooks")
    {:noreply, assign(socket, syncing: false, sync_result: sync_result, qbo: qbo)}
  end

  def handle_info(_, socket) do
    qbo = Integrations.get_integration("quickbooks")
    {:noreply, assign(socket, qbo: qbo)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div>
        <h1>Integrations</h1>
        <p class="deck">Connect external accounting services</p>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>QuickBooks Online</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.5rem;">
              <strong style="font-size: 1.1rem;">QuickBooks Online</strong>
              <%= if @qbo && @qbo.status == "connected" do %>
                <span class="badge badge-asset">Connected</span>
              <% else %>
                <span class="badge badge-expense">Disconnected</span>
              <% end %>
            </div>
            <p style="color: var(--color-muted); margin: 0;">
              Sync your chart of accounts and journal entries from QuickBooks Online.
            </p>
            <%= if @qbo && @qbo.realm_id do %>
              <p style="color: var(--color-muted); margin: 0.25rem 0 0; font-size: 0.85rem;">
                Company ID: {@qbo.realm_id}
              </p>
            <% end %>
            <%= if @qbo && @qbo.last_synced_at do %>
              <p style="color: var(--color-muted); margin: 0.25rem 0 0; font-size: 0.85rem;">
                Last synced: {Calendar.strftime(@qbo.last_synced_at, "%Y-%m-%d %H:%M:%S UTC")}
              </p>
            <% end %>
          </div>

          <div style="display: flex; gap: 0.5rem;">
            <%= if @qbo && @qbo.status == "connected" do %>
              <div style="display: flex; align-items: center; gap: 0.5rem;">
                <form phx-change="select_sync_company">
                  <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
                    <option value="">All Companies</option>
                    <%= for c <- @companies do %>
                      <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
                    <% end %>
                  </select>
                </form>
                <button
                  class="btn btn-primary"
                  phx-click="sync"
                  disabled={@syncing}
                >
                  <%= if @syncing, do: "Syncing...", else: "Sync Now" %>
                </button>
              </div>
              <%= if @can_write do %>
                <button
                  class="btn btn-danger"
                  phx-click="disconnect"
                  data-confirm="Disconnect QuickBooks? This won't delete synced data."
                >
                  Disconnect
                </button>
              <% end %>
            <% else %>
              <.link href={~p"/auth/quickbooks/connect"} class="btn btn-primary">
                Connect to QuickBooks
              </.link>
            <% end %>
          </div>
        </div>

        <%= if @sync_result do %>
          <div style="margin-top: 1rem; padding: 0.75rem; border-radius: 4px; border: 1px solid var(--color-border); background: var(--color-bg-alt, #f8f9fa);">
            <%= case @sync_result do %>
              <% {:ok, results} -> %>
                <strong style="color: #00994d;">Sync completed</strong>
                <ul style="margin: 0.5rem 0 0; padding-left: 1.5rem;">
                  <li>Accounts: {format_sync_count(results.accounts)}</li>
                  <li>Journal Entries: {format_sync_count(results.journal_entries)}</li>
                </ul>
              <% {:error, reason} -> %>
                <strong style="color: #cc0000;">Sync failed</strong>
                <p style="margin: 0.25rem 0 0; color: #cc0000;">{inspect(reason)}</p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_sync_count({:ok, count}), do: "#{count} synced"
  defp format_sync_count({:error, reason}), do: "Error: #{inspect(reason)}"
  defp format_sync_count(_), do: "—"
end
