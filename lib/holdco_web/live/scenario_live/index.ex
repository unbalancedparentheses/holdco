defmodule HoldcoWeb.ScenarioLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Scenarios, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Scenarios.subscribe()

    scenarios = Scenarios.list_scenarios()
    companies = Corporate.list_companies()

    {:ok, assign(socket,
      page_title: "Scenarios",
      scenarios: scenarios,
      companies: companies,
      show_form: false
    )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params), do: assign(socket, show_form: true)
  defp apply_action(socket, :index, _params), do: assign(socket, show_form: false)

  @impl true
  def handle_event("save", %{"scenario" => params}, socket) do
    case Scenarios.create_scenario(params) do
      {:ok, _} ->
        scenarios = Scenarios.list_scenarios()
        {:noreply, assign(socket, scenarios: scenarios, show_form: false) |> put_flash(:info, "Scenario created") |> push_navigate(to: ~p"/scenarios")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create scenario")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scenario = Scenarios.get_scenario!(id)
    Scenarios.delete_scenario(scenario)
    scenarios = Scenarios.list_scenarios()
    {:noreply, assign(socket, scenarios: scenarios) |> put_flash(:info, "Scenario deleted")}
  end

  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, push_navigate(socket, to: ~p"/scenarios")}

  @impl true
  def handle_info(_, socket) do
    scenarios = Scenarios.list_scenarios()
    {:noreply, assign(socket, scenarios: scenarios)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Scenarios</h1>
          <p class="deck">Financial projections and what-if analysis</p>
        </div>
        <.link navigate={~p"/scenarios/new"} class="btn btn-primary">New Scenario</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Company</th>
              <th>Status</th>
              <th>Months</th>
              <th>Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for s <- @scenarios do %>
              <tr>
                <td>
                  <.link navigate={~p"/scenarios/#{s.id}"} class="td-link td-name"><%= s.name %></.link>
                </td>
                <td><%= if s.company, do: s.company.name, else: "---" %></td>
                <td><span class={"tag #{scenario_status_tag(s.status)}"}><%= s.status %></span></td>
                <td class="td-num"><%= s.projection_months %></td>
                <td class="td-mono"><%= if s.inserted_at, do: Calendar.strftime(s.inserted_at, "%Y-%m-%d") %></td>
                <td><button phx-click="delete" phx-value-id={s.id} class="btn btn-danger btn-sm" data-confirm="Delete this scenario?">Del</button></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @scenarios == [] do %>
          <div class="empty-state">No scenarios yet. <.link navigate={~p"/scenarios/new"}>Create one</.link></div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>New Scenario</h3></div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group"><label class="form-label">Name *</label><input type="text" name="scenario[name]" class="form-input" required /></div>
              <div class="form-group"><label class="form-label">Description</label><textarea name="scenario[description]" class="form-input"></textarea></div>
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="scenario[company_id]" class="form-select">
                  <option value="">All companies</option>
                  <%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Base Period</label><input type="text" name="scenario[base_period]" class="form-input" placeholder="e.g. 2025-Q1" /></div>
              <div class="form-group"><label class="form-label">Projection Months</label><input type="number" name="scenario[projection_months]" class="form-input" value="12" min="1" max="120" /></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Create Scenario</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp scenario_status_tag("draft"), do: "tag-lemon"
  defp scenario_status_tag("active"), do: "tag-jade"
  defp scenario_status_tag("archived"), do: "tag-ink"
  defp scenario_status_tag(_), do: "tag-ink"
end
