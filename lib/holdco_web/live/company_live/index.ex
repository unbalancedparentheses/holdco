defmodule HoldcoWeb.CompanyLive.Index do
  use HoldcoWeb, :live_view
  alias Holdco.{Corporate, Banking, Assets}
  alias Holdco.Corporate.Company
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Corporate.subscribe()
    companies = Corporate.list_companies()
    total_cash = Banking.total_balance()
    positions_count = length(Assets.list_holdings())
    active_count = Enum.count(companies, &(&1.wind_down_status == "active"))

    {:ok,
     assign(socket,
       page_title: "Companies",
       companies: companies,
       total_cash: total_cash,
       positions_count: positions_count,
       active_count: active_count,
       sorted_companies: sort_hierarchically(companies),
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
  def handle_event("noop", _, socket), do: {:noreply, socket}

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

    companies = Corporate.list_companies()

    {:noreply,
     assign(socket,
       companies: companies,
       sorted_companies: sort_hierarchically(companies),
       company_tree: Corporate.company_tree()
     )
     |> put_flash(:info, "Company deleted")}
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
  def handle_info({:companies_created, _}, socket) do
    companies = Corporate.list_companies()

    {:noreply,
     assign(socket,
       companies: companies,
       sorted_companies: sort_hierarchically(companies),
       company_tree: Corporate.company_tree()
     )}
  end

  def handle_info({:companies_deleted, _}, socket) do
    companies = Corporate.list_companies()

    {:noreply,
     assign(socket,
       companies: companies,
       sorted_companies: sort_hierarchically(companies),
       company_tree: Corporate.company_tree()
     )}
  end

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

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Entities</div>
        <div class="metric-value">{length(@companies)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value num-positive">{@active_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Cash</div>
        <div class="metric-value">${format_number(@total_cash)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Positions</div>
        <div class="metric-value">{@positions_count}</div>
      </div>
    </div>

    <%= if @company_tree != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Org Chart</h2>
        </div>
        <div class="panel" style="padding: 2rem; overflow-x: auto;">
          <div style="text-align: center;">
            <ul style="padding-top: 0; position: relative; display: inline-flex; justify-content: center; list-style: none; margin: 0; padding-left: 0;">
              <%= for node <- @company_tree do %>
                <li style="display: inline-block; vertical-align: top; text-align: center; list-style-type: none; position: relative; padding: 20px 10px 0 10px;">
                  {render_org_node(assigns, node)}
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>
    <% end %>

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
              <%= for company <- @sorted_companies do %>
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
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>New Company</h3>
          </div>
          <div class="dialog-body">
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

  defp sort_hierarchically(companies) do
    roots = Enum.filter(companies, &is_nil(&1.parent_id)) |> Enum.sort_by(& &1.name)
    children_map = companies |> Enum.filter(& &1.parent_id) |> Enum.group_by(& &1.parent_id)
    Enum.flat_map(roots, &flatten_with_children(&1, children_map))
  end

  defp flatten_with_children(company, children_map) do
    children =
      Map.get(children_map, company.id, [])
      |> Enum.sort_by(& &1.name)

    [company | Enum.flat_map(children, &flatten_with_children(&1, children_map))]
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

  defp render_org_node(assigns, node) do
    company = node.company
    children = node.children
    has_children = children != []

    assigns =
      assigns
      |> Map.put(:org_company, company)
      |> Map.put(:org_children, children)
      |> Map.put(:org_has_children, has_children)

    ~H"""
    <div style={org_card_style(@org_company.wind_down_status)}>
      <.link navigate={~p"/companies/#{@org_company.id}"} style="text-decoration: none; color: inherit;">
        <div style="font-weight: 600; font-size: 0.95rem; margin-bottom: 0.25rem;">
          {@org_company.name}
        </div>
      </.link>
      <div style="font-size: 0.8rem; color: var(--muted); margin-bottom: 0.35rem;">
        {@org_company.country}
      </div>
      <%= if @org_company.category do %>
        <span class="tag tag-ink" style="font-size: 0.7rem; margin-bottom: 0.25rem;">
          {@org_company.category}
        </span>
      <% end %>
      <%= if @org_company.ownership_pct do %>
        <div style="font-size: 0.75rem; color: var(--muted); margin-top: 0.25rem;">
          {@org_company.ownership_pct}% owned
        </div>
      <% end %>
      <div style="margin-top: 0.35rem;">
        <span class={"tag #{status_tag(@org_company.wind_down_status)}"} style="font-size: 0.7rem;">
          {@org_company.wind_down_status}
        </span>
      </div>
    </div>
    <%= if @org_has_children do %>
      <div style="width: 2px; height: 20px; background: var(--rule, #ccc); margin: 0 auto;"></div>
      <%= if length(@org_children) > 1 do %>
        <div style="display: flex; justify-content: center;">
          <div style={"height: 2px; background: var(--rule, #ccc); width: calc(100% - 20px);"}></div>
        </div>
      <% end %>
      <ul style="padding-top: 0; position: relative; display: inline-flex; justify-content: center; list-style: none; margin: 0; padding-left: 0;">
        <%= for child <- @org_children do %>
          <li style="display: inline-block; vertical-align: top; text-align: center; list-style-type: none; position: relative; padding: 0 10px;">
            <div style="width: 2px; height: 20px; background: var(--rule, #ccc); margin: 0 auto;"></div>
            {render_org_node(assigns, child)}
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 0)) |> :erlang.float_to_binary(decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp org_card_style(status) do
    border_color =
      case status do
        "active" -> "var(--jade, #4a8c87)"
        "winding_down" -> "var(--lemon, #b89040)"
        "dissolved" -> "var(--crimson, #b0605e)"
        _ -> "var(--rule, #ccc)"
      end

    "display: inline-block; border: 2px solid #{border_color}; border-radius: 8px; padding: 0.75rem 1rem; min-width: 160px; max-width: 220px; background: var(--card-bg, #fff); text-align: center;"
  end
end
