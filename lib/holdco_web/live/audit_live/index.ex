defmodule HoldcoWeb.AuditLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("audit")

    logs = Platform.list_audit_logs(%{limit: 100})

    {:ok, assign(socket,
      page_title: "Audit Log",
      logs: logs
    )}
  end

  @impl true
  def handle_info({:audit_log_created, log}, socket) do
    logs = [log | Enum.take(socket.assigns.logs, 99)]
    {:noreply, assign(socket, logs: logs)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Audit Log</h1>
      <p class="deck">Real-time activity stream across all entities. Auto-updates as actions occur.</p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Entries</div>
        <div class="metric-value"><%= length(@logs) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Creates</div>
        <div class="metric-value"><%= Enum.count(@logs, &(&1.action == "create")) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Updates</div>
        <div class="metric-value"><%= Enum.count(@logs, &(&1.action == "update")) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Deletes</div>
        <div class="metric-value"><%= Enum.count(@logs, &(&1.action == "delete")) %></div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Activity Stream</h2>
        <span class="count">Latest 100</span>
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
                <td class="td-mono"><%= format_time(log.inserted_at) %></td>
                <td><span class={"tag #{action_tag(log.action)}"}><%= log.action %></span></td>
                <td><%= log.table_name %></td>
                <td class="td-mono">#<%= log.record_id %></td>
                <td><%= log.details %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @logs == [] do %>
          <div class="empty-state">No audit log entries yet. Actions will appear here in real-time.</div>
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
