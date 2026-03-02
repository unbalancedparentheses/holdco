defmodule HoldcoWeb.AccountingLive.Integrations do
  use HoldcoWeb, :live_view

  alias Holdco.{Integrations, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Integrations.subscribe()

    companies = Corporate.list_companies()
    all_integrations = Integrations.list_integrations()

    integration_map = build_integration_map(all_integrations)

    connected = Enum.count(all_integrations, &(&1.status == "connected"))
    disconnected = length(all_integrations) - connected

    now = DateTime.utc_now()

    stale =
      Enum.count(all_integrations, fn i ->
        i.status == "connected" and i.last_synced_at != nil and
          DateTime.diff(now, i.last_synced_at, :hour) > 24
      end)

    last_sync =
      all_integrations
      |> Enum.filter(& &1.last_synced_at)
      |> Enum.max_by(& &1.last_synced_at, DateTime, fn -> nil end)

    {:ok,
     assign(socket,
       page_title: "Integrations",
       companies: companies,
       integration_map: integration_map,
       all_integrations: all_integrations,
       connected: connected,
       disconnected: disconnected,
       stale_count: stale,
       last_sync: last_sync
     )}
  end

  @impl true
  def handle_info(_, socket) do
    all_integrations = Integrations.list_integrations()
    integration_map = build_integration_map(all_integrations)

    connected = Enum.count(all_integrations, &(&1.status == "connected"))
    disconnected = length(all_integrations) - connected

    now = DateTime.utc_now()

    stale =
      Enum.count(all_integrations, fn i ->
        i.status == "connected" and i.last_synced_at != nil and
          DateTime.diff(now, i.last_synced_at, :hour) > 24
      end)

    last_sync =
      all_integrations
      |> Enum.filter(& &1.last_synced_at)
      |> Enum.max_by(& &1.last_synced_at, DateTime, fn -> nil end)

    {:noreply,
     assign(socket,
       integration_map: integration_map,
       all_integrations: all_integrations,
       connected: connected,
       disconnected: disconnected,
       stale_count: stale,
       last_sync: last_sync
     )}
  end

  defp build_integration_map(integrations) do
    Enum.reduce(integrations, %{}, fn i, acc ->
      Map.put(acc, {i.company_id, i.provider}, i)
    end)
  end

  defp provider_label("quickbooks"), do: "QuickBooks"
  defp provider_label("xero"), do: "Xero"
  defp provider_label(other), do: other

  defp sync_health(nil), do: {"tag-ink", "N/A"}
  defp sync_health(%{status: s}) when s != "connected", do: {"tag-ink", "N/A"}
  defp sync_health(%{last_synced_at: nil}), do: {"tag-lemon", "Never Synced"}

  defp sync_health(%{last_synced_at: last_synced}) do
    hours = DateTime.diff(DateTime.utc_now(), last_synced, :hour)

    cond do
      hours < 1 -> {"tag-jade", "Fresh"}
      hours <= 24 -> {"tag-lemon", "Stale"}
      true -> {"tag-crimson", "Outdated"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div>
        <h1>Integrations</h1>
        <p class="deck">Overview of external accounting integrations across all companies</p>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Connected</div>
        <div class="metric-value num-positive">{@connected}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Disconnected</div>
        <div class="metric-value">{@disconnected}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Stale (>24h)</div>
        <div class={"metric-value #{if @stale_count > 0, do: "num-negative"}"}>
          {@stale_count}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Last Sync</div>
        <div class="metric-value" style="font-size: 1rem;">
          {if @last_sync, do: Calendar.strftime(@last_sync.last_synced_at, "%Y-%m-%d %H:%M"), else: "Never"}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Integrations</h2>
        <span class="count">{length(@all_integrations)}</span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Provider</th>
              <th>Status</th>
              <th>Sync Health</th>
              <th>External ID</th>
              <th>Last Synced</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for company <- @companies do %>
              <%= for provider <- ["quickbooks", "xero"] do %>
                <% integration = Map.get(@integration_map, {company.id, provider}) %>
                <tr>
                  <td>
                    <.link navigate={~p"/companies/#{company.id}"} class="td-link">
                      {company.name}
                    </.link>
                  </td>
                  <td>{provider_label(provider)}</td>
                  <td>
                    <%= if integration && integration.status == "connected" do %>
                      <span class="tag tag-jade">Connected</span>
                    <% else %>
                      <span class="tag tag-crimson">Disconnected</span>
                    <% end %>
                  </td>
                  <td>
                    <% {health_class, health_label} = sync_health(integration) %>
                    <span class={"tag #{health_class}"}>{health_label}</span>
                  </td>
                  <td class="td-mono">{if integration, do: integration.realm_id, else: "—"}</td>
                  <td class="td-mono">
                    {if integration && integration.last_synced_at, do: Calendar.strftime(integration.last_synced_at, "%Y-%m-%d %H:%M"), else: "—"}
                  </td>
                  <td>
                    <.link navigate={~p"/companies/#{company.id}"} class="btn btn-sm btn-secondary">
                      Manage
                    </.link>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
        <%= if @companies == [] do %>
          <div class="empty-state">No companies found.</div>
        <% end %>
      </div>
    </div>
    """
  end
end
