defmodule HoldcoWeb.AlertsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @metrics ~w(nav cash_balance holding_value liability_total portfolio_concentration expense_ratio)
  @conditions ~w(above below change_pct_above change_pct_below)
  @severities ~w(info warning critical)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe_alerts()

    {:ok,
     socket
     |> assign(
       page_title: "Alerts",
       tab: "rules",
       filter_status: nil,
       filter_severity: nil,
       show_form: false,
       editing_rule: nil,
       metrics: @metrics,
       conditions: @conditions,
       severities: @severities
     )
     |> reload_data()}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: tab)}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    status = if status == "", do: nil, else: status
    {:noreply, socket |> assign(filter_status: status) |> reload_data()}
  end

  def handle_event("filter_severity", %{"severity" => severity}, socket) do
    severity = if severity == "", do: nil, else: severity
    {:noreply, socket |> assign(filter_severity: severity) |> reload_data()}
  end

  # --- Permission Guards ---
  def handle_event("save_rule", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to manage alert rules")}

  def handle_event("delete_rule", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to delete alert rules")}

  def handle_event("toggle_rule", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to modify alert rules")}

  def handle_event("run_now", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to trigger alert evaluation")}

  # --- Form ---
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_rule: nil)}
  end

  def handle_event("edit_rule", %{"id" => id}, socket) do
    rule = Platform.get_alert_rule!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_rule: rule)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_rule: nil)}
  end

  # --- Create / Update Rule ---
  def handle_event("save_rule", %{"alert_rule" => params}, socket) do
    params = Map.put(params, "created_by_id", socket.assigns.current_scope.user.id)

    result =
      case socket.assigns.editing_rule do
        nil -> Platform.create_alert_rule(params)
        rule -> Platform.update_alert_rule(rule, params)
      end

    case result do
      {:ok, _} ->
        action = if socket.assigns.editing_rule, do: "updated", else: "created"

        {:noreply,
         socket
         |> put_flash(:info, "Alert rule #{action} successfully")
         |> assign(show_form: false, editing_rule: nil)
         |> reload_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save alert rule. Check required fields.")}
    end
  end

  # --- Delete Rule ---
  def handle_event("delete_rule", %{"id" => id}, socket) do
    rule = Platform.get_alert_rule!(String.to_integer(id))

    case Platform.delete_alert_rule(rule) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert rule deleted")
         |> reload_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete alert rule")}
    end
  end

  # --- Toggle Active ---
  def handle_event("toggle_rule", %{"id" => id}, socket) do
    rule = Platform.get_alert_rule!(String.to_integer(id))

    case Platform.update_alert_rule(rule, %{"is_active" => !rule.is_active}) do
      {:ok, _} ->
        {:noreply, reload_data(socket)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle alert rule")}
    end
  end

  # --- Alert Actions ---
  def handle_event("acknowledge_alert", %{"id" => id}, socket) do
    alert = Platform.get_alert!(String.to_integer(id))
    user_id = socket.assigns.current_scope.user.id

    case Platform.acknowledge_alert(alert, user_id) do
      {:ok, _} -> {:noreply, reload_data(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to acknowledge alert")}
    end
  end

  def handle_event("resolve_alert", %{"id" => id}, socket) do
    alert = Platform.get_alert!(String.to_integer(id))

    case Platform.resolve_alert(alert) do
      {:ok, _} -> {:noreply, reload_data(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to resolve alert")}
    end
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    alert = Platform.get_alert!(String.to_integer(id))

    case Platform.mark_alert_read(alert) do
      {:ok, _} -> {:noreply, reload_data(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to mark alert as read")}
    end
  end

  # --- Run Now ---
  def handle_event("run_now", _params, socket) do
    case Holdco.Workers.AlertEngineWorker.perform(%{}) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Alert engine evaluation completed")
         |> reload_data()}

      _ ->
        {:noreply, put_flash(socket, :error, "Alert engine evaluation failed")}
    end
  end

  @impl true
  def handle_info({:new_alert, _alert}, socket) do
    {:noreply, reload_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, reload_data(socket)}

  defp reload_data(socket) do
    rules = Platform.list_alert_rules()
    alert_opts = build_alert_opts(socket.assigns)
    alerts = Platform.list_alerts(alert_opts)
    unread_count = Platform.count_unread_alerts()

    critical_count =
      Enum.count(alerts, fn a -> a.severity == "critical" and a.status in ~w(unread read) end)

    active_rules_count = Enum.count(rules, & &1.is_active)

    assign(socket,
      rules: rules,
      alerts: alerts,
      unread_count: unread_count,
      critical_count: critical_count,
      active_rules_count: active_rules_count
    )
  end

  defp build_alert_opts(assigns) do
    opts = []
    opts = if assigns[:filter_status], do: Keyword.put(opts, :status, assigns.filter_status), else: opts
    opts = if assigns[:filter_severity], do: Keyword.put(opts, :severity, assigns.filter_severity), else: opts
    opts
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Alerts</h1>
      <p class="deck">
        Configure alert rules to monitor portfolio metrics and receive notifications when thresholds are breached.
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Active Rules</div>
        <div class="metric-value">{@active_rules_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unread Alerts</div>
        <div class="metric-value">{@unread_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Critical Alerts</div>
        <div class="metric-value">{@critical_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Rules</div>
        <div class="metric-value">{length(@rules)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <div style="display: flex; gap: 8px;">
          <button
            class={"btn btn-sm #{if @tab == "rules", do: "btn-primary", else: "btn-secondary"}"}
            phx-click="switch_tab"
            phx-value-tab="rules"
          >
            Alert Rules
          </button>
          <button
            class={"btn btn-sm #{if @tab == "alerts", do: "btn-primary", else: "btn-secondary"}"}
            phx-click="switch_tab"
            phx-value-tab="alerts"
          >
            Active Alerts
          </button>
        </div>
        <div style="display: flex; gap: 8px; align-items: center;">
          <%= if @can_write do %>
            <button class="btn btn-sm btn-secondary" phx-click="run_now">
              Run Now
            </button>
            <%= if @tab == "rules" do %>
              <button class="btn btn-sm btn-primary" phx-click="show_form">
                New Rule
              </button>
            <% end %>
          <% end %>
        </div>
      </div>

      <%= if @tab == "rules" do %>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Metric</th>
                <th>Condition</th>
                <th>Threshold</th>
                <th>Target</th>
                <th>Severity</th>
                <th>Active</th>
                <th>Cooldown</th>
                <th>Last Triggered</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for rule <- @rules do %>
                <tr>
                  <td><strong>{rule.name}</strong></td>
                  <td><span class="tag tag-ink">{rule.metric}</span></td>
                  <td>{rule.condition}</td>
                  <td class="td-mono">{format_decimal(rule.threshold)}</td>
                  <td class="td-mono">{rule.target || "-"}</td>
                  <td><span class={"tag #{severity_tag(rule.severity)}"}>{rule.severity}</span></td>
                  <td>
                    <%= if rule.is_active do %>
                      <span class="tag tag-jade">Active</span>
                    <% else %>
                      <span class="tag tag-ink">Inactive</span>
                    <% end %>
                  </td>
                  <td>{rule.cooldown_minutes}m</td>
                  <td class="td-mono">{format_datetime(rule.last_triggered_at)}</td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        class="btn btn-sm btn-secondary"
                        phx-click="toggle_rule"
                        phx-value-id={rule.id}
                      >
                        <%= if rule.is_active, do: "Disable", else: "Enable" %>
                      </button>
                      <button
                        class="btn btn-sm btn-secondary"
                        phx-click="edit_rule"
                        phx-value-id={rule.id}
                      >
                        Edit
                      </button>
                      <button
                        class="btn btn-sm btn-danger"
                        phx-click="delete_rule"
                        phx-value-id={rule.id}
                        data-confirm="Delete this alert rule?"
                      >
                        Del
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @rules == [] do %>
            <div class="empty-state">No alert rules configured yet. Create one to get started.</div>
          <% end %>
        </div>
      <% end %>

      <%= if @tab == "alerts" do %>
        <div style="display: flex; gap: 12px; margin-bottom: 12px;">
          <div>
            <label class="form-label" style="font-size: 0.8rem;">Status</label>
            <select class="form-select" phx-change="filter_status" name="status" style="width: auto;">
              <option value="">All</option>
              <option value="unread" selected={@filter_status == "unread"}>Unread</option>
              <option value="read" selected={@filter_status == "read"}>Read</option>
              <option value="acknowledged" selected={@filter_status == "acknowledged"}>Acknowledged</option>
              <option value="resolved" selected={@filter_status == "resolved"}>Resolved</option>
            </select>
          </div>
          <div>
            <label class="form-label" style="font-size: 0.8rem;">Severity</label>
            <select class="form-select" phx-change="filter_severity" name="severity" style="width: auto;">
              <option value="">All</option>
              <option value="info" selected={@filter_severity == "info"}>Info</option>
              <option value="warning" selected={@filter_severity == "warning"}>Warning</option>
              <option value="critical" selected={@filter_severity == "critical"}>Critical</option>
            </select>
          </div>
        </div>

        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Severity</th>
                <th>Message</th>
                <th>Value</th>
                <th>Threshold</th>
                <th>Status</th>
                <th>Time</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for alert <- @alerts do %>
                <tr>
                  <td><span class={"tag #{severity_tag(alert.severity)}"}>{alert.severity}</span></td>
                  <td>{alert.message}</td>
                  <td class="td-mono">{format_decimal(alert.metric_value)}</td>
                  <td class="td-mono">{format_decimal(alert.threshold_value)}</td>
                  <td><span class={"tag #{status_tag(alert.status)}"}>{alert.status}</span></td>
                  <td class="td-mono">{format_datetime(alert.inserted_at)}</td>
                  <td>
                    <%= if alert.status == "unread" do %>
                      <button class="btn btn-sm btn-secondary" phx-click="mark_read" phx-value-id={alert.id}>
                        Mark Read
                      </button>
                    <% end %>
                    <%= if alert.status in ~w(unread read) do %>
                      <button class="btn btn-sm btn-secondary" phx-click="acknowledge_alert" phx-value-id={alert.id}>
                        Ack
                      </button>
                    <% end %>
                    <%= if alert.status != "resolved" do %>
                      <button class="btn btn-sm btn-primary" phx-click="resolve_alert" phx-value-id={alert.id}>
                        Resolve
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @alerts == [] do %>
            <div class="empty-state">No alerts match the current filters.</div>
          <% end %>
        </div>
      <% end %>
    </div>

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--rule);">
      <span style="font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint);">Related</span>
      <div style="display: flex; gap: 1rem; margin-top: 0.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/anomalies"} class="td-link" style="font-size: 0.85rem;">Anomalies</.link>
        <.link navigate={~p"/notifications"} class="td-link" style="font-size: 0.85rem;">Notifications</.link>
      </div>
    </div>

    <%!-- Create/Edit Rule Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3><%= if @editing_rule, do: "Edit Alert Rule", else: "New Alert Rule" %></h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_rule">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="alert_rule[name]"
                  class="form-input"
                  value={if @editing_rule, do: @editing_rule.name, else: ""}
                  required
                  placeholder="e.g. NAV Below Threshold"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea
                  name="alert_rule[description]"
                  class="form-input"
                  rows="2"
                  placeholder="Optional description..."
                ><%= if @editing_rule, do: @editing_rule.description, else: "" %></textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Metric *</label>
                <select name="alert_rule[metric]" class="form-select" required>
                  <option value="">Select metric...</option>
                  <%= for m <- @metrics do %>
                    <option value={m} selected={@editing_rule && @editing_rule.metric == m}>{m}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Condition *</label>
                <select name="alert_rule[condition]" class="form-select" required>
                  <option value="">Select condition...</option>
                  <%= for c <- @conditions do %>
                    <option value={c} selected={@editing_rule && @editing_rule.condition == c}>{c}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Threshold *</label>
                <input
                  type="number"
                  step="any"
                  name="alert_rule[threshold]"
                  class="form-input"
                  value={if @editing_rule, do: @editing_rule.threshold, else: ""}
                  required
                  placeholder="e.g. 1000000"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Target</label>
                <input
                  type="text"
                  name="alert_rule[target]"
                  class="form-input"
                  value={if @editing_rule, do: @editing_rule.target, else: ""}
                  placeholder="e.g. AAPL (for holding_value metric)"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Severity</label>
                <select name="alert_rule[severity]" class="form-select">
                  <%= for s <- @severities do %>
                    <option value={s} selected={@editing_rule && @editing_rule.severity == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Cooldown (minutes)</label>
                <input
                  type="number"
                  name="alert_rule[cooldown_minutes]"
                  class="form-input"
                  value={if @editing_rule, do: @editing_rule.cooldown_minutes, else: "60"}
                  min="1"
                  placeholder="60"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  <%= if @editing_rule, do: "Update Rule", else: "Create Rule" %>
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp format_decimal(nil), do: "-"
  defp format_decimal(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_decimal(val), do: to_string(val)

  defp severity_tag("critical"), do: "tag-crimson"
  defp severity_tag("warning"), do: "tag-lemon"
  defp severity_tag("info"), do: "tag-ink"
  defp severity_tag(_), do: "tag-ink"

  defp status_tag("unread"), do: "tag-crimson"
  defp status_tag("read"), do: "tag-lemon"
  defp status_tag("acknowledged"), do: "tag-ink"
  defp status_tag("resolved"), do: "tag-jade"
  defp status_tag(_), do: "tag-ink"
end
