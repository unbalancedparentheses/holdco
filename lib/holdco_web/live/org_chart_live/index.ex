defmodule HoldcoWeb.OrgChartLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Corporate

  @impl true
  def mount(_params, _session, socket) do
    tree = Corporate.company_tree()

    {:ok,
     assign(socket,
       page_title: "Org Chart",
       tree: tree
     )}
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
      <div class="section">
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

    assigns =
      assigns
      |> Map.put(:company, company)
      |> Map.put(:children, children)
      |> Map.put(:has_children, has_children)
      |> Map.put(:is_root, is_root)

    ~H"""
    <div style={node_card_style(@company.wind_down_status)}>
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

  defp node_card_style(status) do
    border_color =
      case status do
        "active" -> "var(--jade, #4a8c87)"
        "winding_down" -> "var(--lemon, #b89040)"
        "dissolved" -> "var(--crimson, #b0605e)"
        _ -> "var(--rule, #ccc)"
      end

    "display: inline-block; border: 2px solid #{border_color}; border-radius: 8px; padding: 0.75rem 1rem; min-width: 160px; max-width: 220px; background: var(--card-bg, #fff); text-align: center;"
  end

  defp child_offset(count) when count <= 1, do: 0
  defp child_offset(_count), do: 20

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("winding_down"), do: "tag-lemon"
  defp status_tag("dissolved"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"
end
