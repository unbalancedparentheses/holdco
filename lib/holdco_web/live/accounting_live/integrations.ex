defmodule HoldcoWeb.AccountingLive.Integrations do
  use HoldcoWeb, :live_view

  alias Holdco.{Integrations, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Integrations.subscribe()

    companies = Corporate.list_companies()
    all_integrations = Integrations.list_integrations()

    company_qbo_map =
      Map.new(all_integrations, fn i -> {i.company_id, i} end)

    {:ok,
     assign(socket,
       page_title: "Integrations",
       companies: companies,
       company_qbo_map: company_qbo_map
     )}
  end

  @impl true
  def handle_info(_, socket) do
    all_integrations = Integrations.list_integrations()
    company_qbo_map = Map.new(all_integrations, fn i -> {i.company_id, i} end)
    {:noreply, assign(socket, company_qbo_map: company_qbo_map)}
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
              <% qbo = Map.get(@company_qbo_map, company.id) %>
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
    """
  end
end
