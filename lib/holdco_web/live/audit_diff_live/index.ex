defmodule HoldcoWeb.AuditDiffLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Platform, AuditDiff}

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
    diff_entries = compute_diffs(logs)

    {:ok,
     assign(socket,
       page_title: "Audit Diffs",
       logs: logs,
       diff_entries: diff_entries,
       filters: filters,
       expanded_id: nil
     )}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters = Map.merge(@default_filters, params)
    logs = fetch_logs(filters)
    diff_entries = compute_diffs(logs)
    {:noreply, assign(socket, logs: logs, diff_entries: diff_entries, filters: filters)}
  end

  def handle_event("clear_filters", _, socket) do
    filters = @default_filters
    logs = fetch_logs(filters)
    diff_entries = compute_diffs(logs)
    {:noreply, assign(socket, logs: logs, diff_entries: diff_entries, filters: filters)}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    id = String.to_integer(id)
    current = socket.assigns.expanded_id
    {:noreply, assign(socket, expanded_id: if(current == id, do: nil, else: id))}
  end

  @impl true
  def handle_info({:audit_log_created, log}, socket) do
    if log_matches_filters?(log, socket.assigns.filters) do
      logs = [log | Enum.take(socket.assigns.logs, 99)]
      diff_entries = compute_diffs(logs)
      {:noreply, assign(socket, logs: logs, diff_entries: diff_entries)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # --- Private helpers ---

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

  defp compute_diffs(logs) do
    Enum.map(logs, fn log ->
      diffs = AuditDiff.format_diff(log.old_values, log.new_values)
      %{log: log, diffs: diffs, has_diffs: diffs != []}
    end)
  end

  defp log_matches_filters?(log, filters) do
    matches_field?(log.action, filters["action"]) &&
      matches_field?(log.table_name, filters["table_name"]) &&
      matches_from?(log, filters["from"]) &&
      matches_to?(log, filters["to"])
  end

  defp matches_field?(_val, filter) when filter in [nil, ""], do: true
  defp matches_field?(val, filter), do: val == filter

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

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp action_tag("create"), do: "tag-jade"
  defp action_tag("update"), do: "tag-lemon"
  defp action_tag("delete"), do: "tag-crimson"
  defp action_tag(_), do: "tag-ink"

  defp diff_type(%{old_value: nil, new_value: _}), do: :added
  defp diff_type(%{old_value: _, new_value: nil}), do: :removed
  defp diff_type(_), do: :changed

  defp diff_bg(:added), do: "background: rgba(0, 153, 77, 0.08);"
  defp diff_bg(:removed), do: "background: rgba(204, 0, 0, 0.08);"
  defp diff_bg(:changed), do: "background: rgba(204, 170, 0, 0.08);"

  defp diff_border(:added), do: "border-left: 3px solid #00994d;"
  defp diff_border(:removed), do: "border-left: 3px solid #cc0000;"
  defp diff_border(:changed), do: "border-left: 3px solid #ccaa00;"

  defp diff_label(:added), do: "Added"
  defp diff_label(:removed), do: "Removed"
  defp diff_label(:changed), do: "Changed"

  defp diff_label_tag(:added), do: "tag-jade"
  defp diff_label_tag(:removed), do: "tag-crimson"
  defp diff_label_tag(:changed), do: "tag-lemon"

  defp format_value(nil), do: "(none)"
  defp format_value(val) when is_binary(val), do: val
  defp format_value(val), do: inspect(val)

  defp user_email(log) do
    if is_map(log.user) and not is_nil(log.user) do
      log.user.email
    else
      "---"
    end
  rescue
    _ -> "---"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Audit Diffs</h1>
      <p class="deck">
        Side-by-side comparison of old and new values for every audited change
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
        <div class="metric-value">{length(@diff_entries)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">With Diffs</div>
        <div class="metric-value">{Enum.count(@diff_entries, & &1.has_diffs)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Creates</div>
        <div class="metric-value">{Enum.count(@diff_entries, &(&1.log.action == "create"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Updates</div>
        <div class="metric-value">{Enum.count(@diff_entries, &(&1.log.action == "update"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Change History</h2>
        <span class="count">
          {if filters_active?(@filters), do: "Filtered -- ", else: ""}Latest {length(@diff_entries)}
        </span>
      </div>
      <div class="panel">
        <%= for entry <- @diff_entries do %>
          <div style={"border-bottom: 1px solid var(--color-border); #{if @expanded_id == entry.log.id, do: "background: var(--color-bg-alt);", else: ""}"}>
            <div
              style="display: flex; align-items: center; gap: 0.75rem; padding: 0.6rem 0.75rem; cursor: pointer;"
              phx-click="toggle_expand"
              phx-value-id={entry.log.id}
            >
              <span style="width: 1rem; text-align: center; color: var(--muted);">
                {if @expanded_id == entry.log.id, do: raw("&#9660;"), else: raw("&#9654;")}
              </span>
              <span class="td-mono" style="min-width: 140px; font-size: 0.8rem;">
                {format_time(entry.log.inserted_at)}
              </span>
              <span class={"tag #{action_tag(entry.log.action)}"}>{entry.log.action}</span>
              <span style="font-weight: 600;">{entry.log.table_name}</span>
              <span class="td-mono" style="color: var(--muted);">#{entry.log.record_id}</span>
              <span style="color: var(--muted); font-size: 0.85rem;">{user_email(entry.log)}</span>
              <%= if entry.has_diffs do %>
                <span class="tag tag-lemon" style="font-size: 0.7rem; margin-left: auto;">
                  {length(entry.diffs)} field(s) changed
                </span>
              <% else %>
                <span style="color: var(--muted); font-size: 0.8rem; margin-left: auto;">No diff data</span>
              <% end %>
            </div>

            <%= if @expanded_id == entry.log.id and entry.has_diffs do %>
              <div style="padding: 0 0.75rem 1rem 2.5rem;">
                <table style="width: 100%;">
                  <thead>
                    <tr>
                      <th style="width: 120px;">Field</th>
                      <th style="width: 80px;">Change</th>
                      <th>Old Value</th>
                      <th>New Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for diff <- entry.diffs do %>
                      <% type = diff_type(diff) %>
                      <tr style={"#{diff_bg(type)} #{diff_border(type)}"}>
                        <td style="font-weight: 600;">{diff.field}</td>
                        <td><span class={"tag #{diff_label_tag(type)}"} style="font-size: 0.7rem;">{diff_label(type)}</span></td>
                        <td style={"font-family: 'SF Mono', monospace; font-size: 0.85rem; #{if type == :removed or type == :changed, do: "color: #cc0000;", else: "color: var(--muted);"}"}>
                          {format_value(diff.old_value)}
                        </td>
                        <td style={"font-family: 'SF Mono', monospace; font-size: 0.85rem; #{if type == :added or type == :changed, do: "color: #00994d;", else: "color: var(--muted);"}"}>
                          {format_value(diff.new_value)}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>

            <%= if @expanded_id == entry.log.id and not entry.has_diffs do %>
              <div style="padding: 0 0.75rem 1rem 2.5rem;">
                <div class="empty-state" style="padding: 0.75rem;">
                  No old/new value data recorded for this audit entry.
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @diff_entries == [] do %>
          <div class="empty-state">
            <%= if filters_active?(@filters) do %>
              No audit log entries match the current filters.
            <% else %>
              No audit log entries yet. Changes will appear here with full diff information.
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
