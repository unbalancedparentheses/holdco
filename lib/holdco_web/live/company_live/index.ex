defmodule HoldcoWeb.CompanyLive.Index do
  use HoldcoWeb, :live_view
  alias Holdco.Corporate
  alias Holdco.Corporate.Company

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Corporate.subscribe()
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Companies",
       companies: companies,
       changeset: Corporate.change_company(%Company{}),
       view_mode: :list,
       company_tree: Corporate.company_tree(),
       expanded_nodes: MapSet.new()
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params),
    do:
      assign(socket,
        show_form: true,
        company: %Company{},
        changeset: Corporate.change_company(%Company{})
      )

  defp apply_action(socket, :index, _params), do: assign(socket, show_form: false, company: nil)

  @impl true
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"company" => params}, socket) do
    case Corporate.create_company(params) do
      {:ok, _company} ->
        {:noreply,
         socket |> put_flash(:info, "Company created") |> push_navigate(to: ~p"/companies")}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    company = Corporate.get_company!(id)
    {:ok, _} = Corporate.delete_company(company)

    {:noreply,
     assign(socket, companies: Corporate.list_companies()) |> put_flash(:info, "Company deleted")}
  end

  def handle_event("close_form", _, socket),
    do: {:noreply, push_navigate(socket, to: ~p"/companies")}

  def handle_event("set_view", %{"mode" => "tree"}, socket) do
    {:noreply, assign(socket, view_mode: :tree)}
  end

  def handle_event("set_view", %{"mode" => "list"}, socket) do
    {:noreply, assign(socket, view_mode: :list)}
  end

  def handle_event("toggle_node", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = socket.assigns.expanded_nodes

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, assign(socket, expanded_nodes: expanded)}
  end

  def handle_event("expand_all", _, socket) do
    all_ids =
      socket.assigns.companies
      |> Enum.filter(fn c -> has_children?(c.id, socket.assigns.company_tree) end)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    {:noreply, assign(socket, expanded_nodes: all_ids)}
  end

  def handle_event("collapse_all", _, socket) do
    {:noreply, assign(socket, expanded_nodes: MapSet.new())}
  end

  @impl true
  def handle_info({:companies_created, _}, socket),
    do:
      {:noreply,
       assign(socket,
         companies: Corporate.list_companies(),
         company_tree: Corporate.company_tree()
       )}

  def handle_info({:companies_deleted, _}, socket),
    do:
      {:noreply,
       assign(socket,
         companies: Corporate.list_companies(),
         company_tree: Corporate.company_tree()
       )}

  def handle_info(_, socket), do: {:noreply, socket}

  defp has_children?(company_id, tree) do
    Enum.any?(tree, fn node ->
      (node.company.id == company_id and node.children != []) or
        has_children?(company_id, node.children)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Companies</h1>
          <p class="deck">{length(@companies)} entities in the corporate structure</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <div class="view-toggle">
            <button
              phx-click="set_view"
              phx-value-mode="list"
              class={"view-toggle-btn #{if @view_mode == :list, do: "active"}"}
            >
              List
            </button>
            <button
              phx-click="set_view"
              phx-value-mode="tree"
              class={"view-toggle-btn #{if @view_mode == :tree, do: "active"}"}
            >
              Tree
            </button>
          </div>
          <a href={~p"/export/companies.csv"} class="btn btn-secondary">
            Export CSV
          </a>
          <%= if @can_write do %>
            <.link navigate={~p"/import?type=companies"} class="btn btn-secondary">
              Import CSV
            </.link>
            <.link navigate={~p"/companies/new"} class="btn btn-primary">New Company</.link>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="panel">
        <%= if @view_mode == :list do %>
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
                    <.link navigate={~p"/companies/#{company.id}"} class="td-link td-name">
                      {company.name}
                    </.link>
                    <%= if company.is_holding do %>
                      <span class="tag tag-teal" style="margin-left:0.5rem">Holding</span>
                    <% end %>
                  </td>
                  <td>{company.country}</td>
                  <td>{company.category}</td>
                  <td class="td-num">
                    {if company.ownership_pct, do: "#{company.ownership_pct}%", else: "---"}
                  </td>
                  <td>
                    <span class={"tag #{kyc_tag(company.kyc_status)}"}>{company.kyc_status}</span>
                  </td>
                  <td>
                    <span class={"tag #{status_tag(company.wind_down_status)}"}>
                      {company.wind_down_status}
                    </span>
                  </td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="delete"
                        phx-value-id={company.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this company?"
                      >
                        Delete
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% else %>
          <div style="padding: 0.5rem 1.25rem 0; display: flex; gap: 0.5rem;">
            <button phx-click="expand_all" class="btn btn-secondary btn-sm">Expand all</button>
            <button phx-click="collapse_all" class="btn btn-secondary btn-sm">Collapse all</button>
          </div>
          <div class="company-tree">
            <ul>
              <%= for node <- @company_tree do %>
                <li>
                  {render_tree_node(assigns, node)}
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
        <%= if @companies == [] do %>
          <div class="empty-state">
            No companies yet. <.link navigate={~p"/companies/new"}>Create one</.link>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @live_action == :new do %>
      <div class="modal-overlay">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header">
            <h3>New Company</h3>
          </div>
          <div class="modal-body">
            <.form for={@changeset} phx-submit="save">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="company[name]"
                  value={@changeset.changes[:name]}
                  class="form-input"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Country *</label>
                <input
                  type="text"
                  name="company[country]"
                  value={@changeset.changes[:country]}
                  class="form-input"
                  required
                />
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
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Ownership %</label>
                <input
                  type="number"
                  name="company[ownership_pct]"
                  class="form-input"
                  min="0"
                  max="100"
                />
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

  defp render_tree_node(parent_assigns, node) do
    company = node.company
    children = node.children
    has_children = children != []
    expanded = MapSet.member?(parent_assigns.expanded_nodes, company.id)

    assigns =
      parent_assigns
      |> Map.put(:node_company, company)
      |> Map.put(:node_children, children)
      |> Map.put(:has_children, has_children)
      |> Map.put(:expanded, expanded)
      |> Map.put(:parent_assigns, parent_assigns)

    ~H"""
    <div class="tree-node">
      <%= if @has_children do %>
        <button
          phx-click="toggle_node"
          phx-value-id={@node_company.id}
          class="tree-toggle"
          title={if @expanded, do: "Collapse", else: "Expand"}
        >
          {if @expanded, do: raw("&minus;"), else: raw("+")}
        </button>
      <% else %>
        <span class="tree-toggle-placeholder"></span>
      <% end %>
      <.link navigate={~p"/companies/#{@node_company.id}"} class="tree-name">
        {@node_company.name}
      </.link>
      <%= if @node_company.is_holding do %>
        <span class="tag tag-teal">Holding</span>
      <% end %>
      <div class="tree-meta">
        <%= if @node_company.country do %>
          <span class="tag tag-ink">{@node_company.country}</span>
        <% end %>
        <span class={"tag #{status_tag(@node_company.wind_down_status)}"}>
          {@node_company.wind_down_status}
        </span>
        <%= if @node_company.ownership_pct do %>
          <span style="font-family: var(--data); font-size: 0.6875rem; color: var(--ink-faint);">
            {@node_company.ownership_pct}%
          </span>
        <% end %>
      </div>
    </div>
    <%= if @has_children and @expanded do %>
      <ul>
        <%= for child <- @node_children do %>
          <li>
            {render_tree_node(@parent_assigns, child)}
          </li>
        <% end %>
      </ul>
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
