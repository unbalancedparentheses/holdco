defmodule HoldcoWeb.ActivityLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Platform.subscribe("platform")
    end

    events = Platform.list_recent_activity(%{limit: 50})
    summary = Platform.activity_summary(%{days: 30})

    {:ok,
     assign(socket,
       page_title: "Activity Feed",
       events: events,
       summary: summary,
       filter_action: nil,
       filter_entity_type: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_action", %{"action" => action}, socket) do
    action = if action == "", do: nil, else: action
    events = Platform.list_recent_activity(%{limit: 50, action: action, entity_type: socket.assigns.filter_entity_type})
    {:noreply, assign(socket, events: events, filter_action: action)}
  end

  def handle_event("filter_entity_type", %{"entity_type" => entity_type}, socket) do
    entity_type = if entity_type == "", do: nil, else: entity_type
    events = Platform.list_recent_activity(%{limit: 50, action: socket.assigns.filter_action, entity_type: entity_type})
    {:noreply, assign(socket, events: events, filter_entity_type: entity_type)}
  end

  def handle_event("clear_filters", _, socket) do
    events = Platform.list_recent_activity(%{limit: 50})
    {:noreply, assign(socket, events: events, filter_action: nil, filter_entity_type: nil)}
  end

  @impl true
  def handle_info({:activity_event_created, _event}, socket) do
    events = Platform.list_recent_activity(%{limit: 50, action: socket.assigns.filter_action, entity_type: socket.assigns.filter_entity_type})
    summary = Platform.activity_summary(%{days: 30})
    {:noreply, assign(socket, events: events, summary: summary)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Activity Feed</h1>
          <p class="deck">Real-time timeline of actions across all contexts</p>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Events</div>
        <div class="metric-value">{length(@events)}</div>
      </div>
      <%= for {action, count} <- Enum.take(Enum.sort_by(@summary, fn {_, c} -> -c end), 4) do %>
        <div class="metric-cell">
          <div class="metric-label">{humanize(action)}</div>
          <div class="metric-value">{count}</div>
        </div>
      <% end %>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Filters</h2>
      </div>
      <div class="panel" style="padding: 1rem; display: flex; gap: 1rem; align-items: center;">
        <form phx-change="filter_action" style="display: inline;">
          <select name="action" class="form-select">
            <option value="">All Actions</option>
            <%= for a <- ~w(created updated deleted approved rejected locked unlocked exported imported dispatched) do %>
              <option value={a} selected={@filter_action == a}>{humanize(a)}</option>
            <% end %>
          </select>
        </form>
        <form phx-change="filter_entity_type" style="display: inline;">
          <input type="text" name="entity_type" class="form-input" placeholder="Entity type..." value={@filter_entity_type || ""} />
        </form>
        <button phx-click="clear_filters" class="btn btn-secondary btn-sm">Clear</button>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Timeline</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Time</th><th>Actor</th><th>Action</th><th>Entity</th>
              <th>Context</th><th>Details</th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @events do %>
              <tr>
                <td class="td-mono">{format_time(e.inserted_at)}</td>
                <td>{e.actor_email || "System"}</td>
                <td><span class={"tag #{action_tag(e.action)}"}>{humanize(e.action)}</span></td>
                <td class="td-name">{e.entity_name || "#{e.entity_type} ##{e.entity_id}"}</td>
                <td class="td-mono">{e.context_module || "---"}</td>
                <td>{if e.metadata && map_size(e.metadata) > 0, do: inspect(e.metadata), else: "---"}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @events == [] do %>
          <div class="empty-state">
            <p>No activity events found.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp humanize(str) when is_binary(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  defp humanize(nil), do: "---"

  defp format_time(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp action_tag("created"), do: "tag-jade"
  defp action_tag("updated"), do: "tag-sky"
  defp action_tag("deleted"), do: "tag-lemon"
  defp action_tag("approved"), do: "tag-jade"
  defp action_tag("rejected"), do: "tag-lemon"
  defp action_tag(_), do: ""
end
