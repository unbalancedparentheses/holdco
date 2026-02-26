defmodule HoldcoWeb.AuditLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @default_filters %{
    "action" => "",
    "table_name" => "",
    "from" => "",
    "to" => ""
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("audit")

    filters = @default_filters
    logs = fetch_logs(filters)

    {:ok,
     assign(socket,
       page_title: "Audit Log",
       logs: logs,
       filters: filters
     )}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters = Map.merge(@default_filters, params)
    logs = fetch_logs(filters)
    {:noreply, assign(socket, logs: logs, filters: filters)}
  end

  def handle_event("clear_filters", _, socket) do
    filters = @default_filters
    logs = fetch_logs(filters)
    {:noreply, assign(socket, logs: logs, filters: filters)}
  end

  @impl true
  def handle_info({:audit_log_created, log}, socket) do
    if log_matches_filters?(log, socket.assigns.filters) do
      logs = [log | Enum.take(socket.assigns.logs, 99)]
      {:noreply, assign(socket, logs: logs)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp fetch_logs(filters) do
    opts =
      %{limit: 100}
      |> put_filter(:action, filters["action"])
      |> put_filter(:table_name, filters["table_name"])
      |> put_filter(:from, filters["from"])
      |> put_filter(:to, filters["to"])

    Platform.list_audit_logs(opts)
  end

  defp put_filter(opts, _key, val) when val in [nil, ""], do: opts
  defp put_filter(opts, key, val), do: Map.put(opts, key, val)

  defp log_matches_filters?(log, filters) do
    matches_action?(log, filters["action"]) &&
      matches_table_name?(log, filters["table_name"]) &&
      matches_from?(log, filters["from"]) &&
      matches_to?(log, filters["to"])
  end

  defp matches_action?(_log, val) when val in [nil, ""], do: true
  defp matches_action?(log, action), do: log.action == action

  defp matches_table_name?(_log, val) when val in [nil, ""], do: true
  defp matches_table_name?(log, table_name), do: log.table_name == table_name

  defp matches_from?(_log, val) when val in [nil, ""], do: true

  defp matches_from?(log, from_str) do
    case Date.from_iso8601(from_str) do
      {:ok, date} ->
        dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        DateTime.compare(log.inserted_at, dt) in [:gt, :eq]

      _ ->
        true
    end
  end

  defp matches_to?(_log, val) when val in [nil, ""], do: true

  defp matches_to?(log, to_str) do
    case Date.from_iso8601(to_str) do
      {:ok, date} ->
        dt = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        DateTime.compare(log.inserted_at, dt) in [:lt, :eq]

      _ ->
        true
    end
  end

  defp filters_active?(filters) do
    Enum.any?(@default_filters, fn {key, default} ->
      Map.get(filters, key, default) != default
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Audit Log</h1>
      <p class="deck">
        Real-time activity stream across all entities. Auto-updates as actions occur.
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Filters</h2>
        <%= if filters_active?(@filters) do %>
          <span class="tag tag-lemon">Filtered</span>
        <% end %>
      </div>
      <div class="panel" style="padding: 1rem;">
        <form phx-submit="filter">
          <div style="display: flex; gap: 1rem; flex-wrap: wrap; align-items: flex-end;">
            <div class="form-group" style="margin-bottom: 0; min-width: 160px;">
              <label class="form-label">Action</label>
              <select name="filters[action]" class="form-select">
                <option value="" selected={@filters["action"] == ""}>All</option>
                <option value="create" selected={@filters["action"] == "create"}>create</option>
                <option value="update" selected={@filters["action"] == "update"}>update</option>
                <option value="delete" selected={@filters["action"] == "delete"}>delete</option>
                <option value="backup_completed" selected={@filters["action"] == "backup_completed"}>
                  backup_completed
                </option>
                <option value="webhook_failed" selected={@filters["action"] == "webhook_failed"}>
                  webhook_failed
                </option>
                <option value="sanctions_match" selected={@filters["action"] == "sanctions_match"}>
                  sanctions_match
                </option>
              </select>
            </div>
            <div class="form-group" style="margin-bottom: 0; min-width: 160px;">
              <label class="form-label">Table Name</label>
              <input
                type="text"
                name="filters[table_name]"
                class="form-input"
                value={@filters["table_name"]}
                placeholder="e.g. companies"
              />
            </div>
            <div class="form-group" style="margin-bottom: 0; min-width: 160px;">
              <label class="form-label">From</label>
              <input
                type="date"
                name="filters[from]"
                class="form-input"
                value={@filters["from"]}
              />
            </div>
            <div class="form-group" style="margin-bottom: 0; min-width: 160px;">
              <label class="form-label">To</label>
              <input type="date" name="filters[to]" class="form-input" value={@filters["to"]} />
            </div>
            <div class="form-group" style="margin-bottom: 0; display: flex; gap: 0.5rem;">
              <button type="submit" class="btn btn-primary">Filter</button>
              <button type="button" phx-click="clear_filters" class="btn btn-secondary">Clear</button>
            </div>
          </div>
        </form>
      </div>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Entries</div>
        <div class="metric-value">{length(@logs)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Creates</div>
        <div class="metric-value">{Enum.count(@logs, &(&1.action == "create"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Updates</div>
        <div class="metric-value">{Enum.count(@logs, &(&1.action == "update"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Deletes</div>
        <div class="metric-value">{Enum.count(@logs, &(&1.action == "delete"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Activity Stream</h2>
        <span class="count">
          {if filters_active?(@filters), do: "Filtered — ", else: ""}Latest {length(@logs)}
        </span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Time</th>
              <th>Action</th>
              <th>Table</th>
              <th>Record ID</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            <%= for log <- @logs do %>
              <tr>
                <td class="td-mono">{format_time(log.inserted_at)}</td>
                <td><span class={"tag #{action_tag(log.action)}"}>{log.action}</span></td>
                <td>{log.table_name}</td>
                <td class="td-mono">#{log.record_id}</td>
                <td>{log.details}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @logs == [] do %>
          <div class="empty-state">
            <%= if filters_active?(@filters) do %>
              No audit log entries match the current filters.
            <% else %>
              No audit log entries yet. Actions will appear here in real-time.
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp action_tag("create"), do: "tag-jade"
  defp action_tag("update"), do: "tag-lemon"
  defp action_tag("delete"), do: "tag-crimson"
  defp action_tag(_), do: "tag-ink"
end
