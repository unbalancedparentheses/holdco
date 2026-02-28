defmodule HoldcoWeb.AccountingLive.Integrations do
  use HoldcoWeb, :live_view

  alias Holdco.{Integrations, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Integrations.subscribe()

    companies = Corporate.list_companies()
    all_integrations = Integrations.list_integrations()

    integration_map = build_integration_map(all_integrations)

    {:ok,
     assign(socket,
       page_title: "Integrations",
       companies: companies,
       integration_map: integration_map
     )}
  end

  @impl true
  def handle_info(_, socket) do
    all_integrations = Integrations.list_integrations()
    integration_map = build_integration_map(all_integrations)
    {:noreply, assign(socket, integration_map: integration_map)}
  end

  defp build_integration_map(integrations) do
    Enum.reduce(integrations, %{}, fn i, acc ->
      Map.put(acc, {i.company_id, i.provider}, i)
    end)
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

    <div class="section">
      <div class="section-head">
        <h2>QuickBooks Online — All Companies</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Provider</th>
              <th>Status</th>
              <th>QBO Company ID</th>
              <th>Last Synced</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for company <- @companies do %>
              <% qbo = Map.get(@integration_map, {company.id, "quickbooks"}) %>
              <tr>
                <td>
                  <.link navigate={~p"/companies/#{company.id}"} class="link">
                    {company.name}
                  </.link>
                </td>
                <td>QuickBooks</td>
                <td>
                  <%= if qbo && qbo.status == "connected" do %>
                    <span class="badge badge-asset">Connected</span>
                  <% else %>
                    <span class="badge badge-expense">Disconnected</span>
                  <% end %>
                </td>
                <td class="td-mono">{if qbo, do: qbo.realm_id, else: "—"}</td>
                <td>
                  <%= if qbo && qbo.last_synced_at do %>
                    {Calendar.strftime(qbo.last_synced_at, "%Y-%m-%d %H:%M:%S UTC")}
                  <% else %>
                    —
                  <% end %>
                </td>
                <td>
                  <.link navigate={~p"/companies/#{company.id}"} class="btn btn-sm btn-primary">
                    Manage
                  </.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @companies == [] do %>
          <div class="empty-state">No companies found.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Xero — All Companies</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Provider</th>
              <th>Status</th>
              <th>Xero Tenant ID</th>
              <th>Last Synced</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for company <- @companies do %>
              <% xero = Map.get(@integration_map, {company.id, "xero"}) %>
              <tr>
                <td>
                  <.link navigate={~p"/companies/#{company.id}"} class="link">
                    {company.name}
                  </.link>
                </td>
                <td>Xero</td>
                <td>
                  <%= if xero && xero.status == "connected" do %>
                    <span class="badge badge-asset">Connected</span>
                  <% else %>
                    <span class="badge badge-expense">Disconnected</span>
                  <% end %>
                </td>
                <td class="td-mono">{if xero, do: xero.realm_id, else: "—"}</td>
                <td>
                  <%= if xero && xero.last_synced_at do %>
                    {Calendar.strftime(xero.last_synced_at, "%Y-%m-%d %H:%M:%S UTC")}
                  <% else %>
                    —
                  <% end %>
                </td>
                <td>
                  <%= if xero && xero.status == "connected" do %>
                    <.link navigate={~p"/companies/#{company.id}"} class="btn btn-sm btn-primary">
                      Manage
                    </.link>
                  <% else %>
                    <.link
                      href={~p"/auth/xero/connect?company_id=#{company.id}"}
                      class="btn btn-sm btn-primary"
                    >
                      Connect
                    </.link>
                  <% end %>
                </td>
              </tr>
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
