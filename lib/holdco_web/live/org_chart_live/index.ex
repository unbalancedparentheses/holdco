defmodule HoldcoWeb.OrgChartLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Banking, Assets}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    tree = Corporate.company_tree()

    companies = Corporate.list_companies()
    bank_accounts = Banking.list_bank_accounts()
    holdings = Assets.list_holdings()

    total_entities = length(companies)
    active_entities = Enum.count(companies, &(&1.wind_down_status == "active"))
    countries = companies |> Enum.map(& &1.country) |> Enum.uniq() |> length()

    # Balance per company for overlay
    balance_by_company =
      bank_accounts
      |> Enum.group_by(& &1.company_id)
      |> Enum.map(fn {cid, accs} ->
        total =
          Enum.reduce(accs, Decimal.new(0), fn a, sum ->
            Money.add(sum, Money.to_decimal(a.balance || 0))
          end)

        {cid, total}
      end)
      |> Map.new()

    holdings_by_company =
      holdings
      |> Enum.group_by(& &1.company_id)
      |> Enum.map(fn {cid, hs} -> {cid, length(hs)} end)
      |> Map.new()

    {:ok,
     assign(socket,
       page_title: "Org Chart",
       tree: tree,
       total_entities: total_entities,
       active_entities: active_entities,
       countries: countries,
       balance_by_company: balance_by_company,
       holdings_by_company: holdings_by_company,
       search_filter: ""
     )}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign(socket, search_filter: String.downcase(query))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Org Chart</h1>
          <p class="deck">Corporate structure and ownership hierarchy</p>
        </div>
        <.link navigate={~p"/companies"} class="btn btn-secondary">List View</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @tree == [] do %>
      <div class="section">
        <div class="panel">
          <div class="empty-state">
            <p>No companies found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Add companies to see the organizational chart. Parent-child relationships
              will be displayed as a tree structure.
            </p>
            <%= if @can_write do %>
              <.link navigate={~p"/companies/new"} class="btn btn-primary">Add Company</.link>
            <% end %>
          </div>
        </div>
      </div>
    <% else %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Entities</div>
          <div class="metric-value">{@total_entities}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Active</div>
          <div class="metric-value num-positive">{@active_entities}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Countries</div>
          <div class="metric-value">{@countries}</div>
        </div>
      </div>

      <div class="section">
        <div style="margin-bottom: 1rem;">
          <form phx-change="search" style="display: flex; align-items: center; gap: 0.5rem;">
            <input
              type="text"
              name="q"
              value={@search_filter}
              placeholder="Search entities..."
              class="form-input"
              style="max-width: 300px;"
              phx-debounce="200"
            />
          </form>
        </div>

        <div class="panel" style="padding: 2rem; overflow-x: auto;">
          <div style="text-align: center;">
            <ul style="padding-top: 0; position: relative; display: inline-flex; justify-content: center; list-style: none; margin: 0; padding-left: 0;">
              <%= for node <- @tree do %>
                <li style="display: inline-block; vertical-align: top; text-align: center; list-style-type: none; position: relative; padding: 20px 10px 0 10px;">
                  {render_node(assigns, node, true)}
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Legend</h2>
        </div>
        <div class="panel" style="padding: 1rem; display: flex; gap: 1.5rem; flex-wrap: wrap;">
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <span class="tag tag-jade">active</span>
            <span style="font-size: 0.85rem; color: var(--muted);">Active entity</span>
          </div>
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <span class="tag tag-lemon">winding_down</span>
            <span style="font-size: 0.85rem; color: var(--muted);">Winding down</span>
          </div>
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <span class="tag tag-crimson">dissolved</span>
            <span style="font-size: 0.85rem; color: var(--muted);">Dissolved</span>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_node(assigns, node, is_root) do
    company = node.company
    children = node.children
    has_children = children != []

    match =
      if assigns.search_filter == "" do
        true
      else
        String.contains?(String.downcase(company.name || ""), assigns.search_filter) or
          String.contains?(String.downcase(company.country || ""), assigns.search_filter)
      end

    assigns =
      assigns
      |> Map.put(:company, company)
      |> Map.put(:children, children)
      |> Map.put(:has_children, has_children)
      |> Map.put(:is_root, is_root)
      |> Map.put(:match, match)

    ~H"""
    <div style={node_card_style(@company.wind_down_status, @search_filter != "" and not @match)}>
      <.link navigate={~p"/companies/#{@company.id}"} style="text-decoration: none; color: inherit;">
        <div style="font-weight: 600; font-size: 0.95rem; margin-bottom: 0.25rem;">
          {@company.name}
        </div>
      </.link>
      <div style="font-size: 0.8rem; color: var(--muted); margin-bottom: 0.35rem;">
        {@company.country}
      </div>
      <%= if @company.category do %>
        <span class="tag tag-ink" style="font-size: 0.7rem; margin-bottom: 0.25rem;">
          {@company.category}
        </span>
      <% end %>
      <%= if @company.ownership_pct do %>
        <div style="font-size: 0.75rem; color: var(--muted); margin-top: 0.25rem;">
          {@company.ownership_pct}% owned
        </div>
      <% end %>
      <div style="margin-top: 0.35rem;">
        <span class={"tag #{status_tag(@company.wind_down_status)}"} style="font-size: 0.7rem;">
          {@company.wind_down_status}
        </span>
      </div>
      <div style="font-size: 0.7rem; color: var(--muted); margin-top: 0.35rem; border-top: 1px solid var(--rule); padding-top: 0.3rem;">
        <%= if bal = Map.get(@balance_by_company, @company.id) do %>
          <div>Cash: ${format_number(bal)}</div>
        <% end %>
        <%= if count = Map.get(@holdings_by_company, @company.id) do %>
          <div>{count} holdings</div>
        <% end %>
      </div>
    </div>
    <%= if @has_children do %>
      <%!-- Vertical connector line down from parent --%>
      <div style="width: 2px; height: 20px; background: var(--rule, #ccc); margin: 0 auto;"></div>
      <%!-- Horizontal connector line across children --%>
      <%= if length(@children) > 1 do %>
        <div style="display: flex; justify-content: center;">
          <div style={"height: 2px; background: var(--rule, #ccc); width: calc(100% - #{child_offset(length(@children))}px);"}></div>
        </div>
      <% end %>
      <ul style="padding-top: 0; position: relative; display: inline-flex; justify-content: center; list-style: none; margin: 0; padding-left: 0;">
        <%= for child <- @children do %>
          <li style="display: inline-block; vertical-align: top; text-align: center; list-style-type: none; position: relative; padding: 0 10px;">
            <%!-- Vertical connector line down to child --%>
            <div style="width: 2px; height: 20px; background: var(--rule, #ccc); margin: 0 auto;"></div>
            {render_node(assigns, child, false)}
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end

  defp node_card_style(status, dimmed) do
    border_color =
      case status do
        "active" -> "var(--jade, #4a8c87)"
        "winding_down" -> "var(--lemon, #b89040)"
        "dissolved" -> "var(--crimson, #b0605e)"
        _ -> "var(--rule, #ccc)"
      end

    opacity = if dimmed, do: "opacity: 0.2;", else: ""

    "display: inline-block; border: 2px solid #{border_color}; border-radius: 8px; padding: 0.75rem 1rem; min-width: 160px; max-width: 220px; background: var(--card-bg, #fff); text-align: center; #{opacity}"
  end

  defp child_offset(count) when count <= 1, do: 0
  defp child_offset(_count), do: 20

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("winding_down"), do: "tag-lemon"
  defp status_tag("dissolved"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"

  defp format_number(%Decimal{} = n),
    do: :erlang.float_to_binary(Money.to_float(n), decimals: 0) |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
