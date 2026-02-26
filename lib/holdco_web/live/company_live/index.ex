defmodule HoldcoWeb.CompanyLive.Index do
  use HoldcoWeb, :live_view
  alias Holdco.Corporate
  alias Holdco.Corporate.Company

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Corporate.subscribe()
    companies = Corporate.list_companies()
    {:ok, assign(socket, page_title: "Companies", companies: companies, changeset: Corporate.change_company(%Company{}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params), do: assign(socket, show_form: true, company: %Company{}, changeset: Corporate.change_company(%Company{}))
  defp apply_action(socket, :index, _params), do: assign(socket, show_form: false, company: nil)

  @impl true
  def handle_event("save", %{"company" => params}, socket) do
    case Corporate.create_company(params) do
      {:ok, _company} ->
        {:noreply, socket |> put_flash(:info, "Company created") |> push_navigate(to: ~p"/companies")}
      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    company = Corporate.get_company!(id)
    {:ok, _} = Corporate.delete_company(company)
    {:noreply, assign(socket, companies: Corporate.list_companies()) |> put_flash(:info, "Company deleted")}
  end

  def handle_event("close_form", _, socket), do: {:noreply, push_navigate(socket, to: ~p"/companies")}

  @impl true
  def handle_info({:companies_created, _}, socket), do: {:noreply, assign(socket, companies: Corporate.list_companies())}
  def handle_info({:companies_deleted, _}, socket), do: {:noreply, assign(socket, companies: Corporate.list_companies())}
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Companies</h1>
          <p class="deck"><%= length(@companies) %> entities in the corporate structure</p>
        </div>
        <.link navigate={~p"/companies/new"} class="btn btn-primary">New Company</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Country</th>
              <th>Category</th>
              <th>Ownership</th>
              <th>KYC</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for company <- @companies do %>
              <tr>
                <td class={if company.parent_id, do: "indent"}>
                  <.link navigate={~p"/companies/#{company.id}"} class="td-link td-name"><%= company.name %></.link>
                  <%= if company.is_holding do %><span class="tag tag-teal" style="margin-left:0.5rem">Holding</span><% end %>
                </td>
                <td><%= company.country %></td>
                <td><%= company.category %></td>
                <td class="td-num"><%= if company.ownership_pct, do: "#{company.ownership_pct}%", else: "---" %></td>
                <td><span class={"tag #{kyc_tag(company.kyc_status)}"}><%= company.kyc_status %></span></td>
                <td><span class={"tag #{status_tag(company.wind_down_status)}"}><%= company.wind_down_status %></span></td>
                <td>
                  <button phx-click="delete" phx-value-id={company.id} class="btn btn-danger btn-sm" data-confirm="Delete this company?">Delete</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @companies == [] do %>
          <div class="empty-state">No companies yet. <.link navigate={~p"/companies/new"}>Create one</.link></div>
        <% end %>
      </div>
    </div>

    <%= if @live_action == :new do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>New Company</h3></div>
          <div class="modal-body">
            <.form for={@changeset} phx-submit="save">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="company[name]" value={@changeset.changes[:name]} class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Country *</label>
                <input type="text" name="company[country]" value={@changeset.changes[:country]} class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Category</label>
                <input type="text" name="company[category]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Parent Company</label>
                <select name="company[parent_id]" class="form-select">
                  <option value="">None (top-level)</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}><%= c.name %></option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Ownership %</label>
                <input type="number" name="company[ownership_pct]" class="form-input" min="0" max="100" />
              </div>
              <div class="form-group">
                <label class="form-label">
                  <input type="checkbox" name="company[is_holding]" value="true" /> Holding company
                </label>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Create Company</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp kyc_tag("approved"), do: "tag-jade"
  defp kyc_tag("in_progress"), do: "tag-lemon"
  defp kyc_tag("rejected"), do: "tag-crimson"
  defp kyc_tag(_), do: "tag-ink"

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("winding_down"), do: "tag-lemon"
  defp status_tag("dissolved"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"
end
