defmodule HoldcoWeb.AnomalyLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    anomalies = Analytics.list_anomalies()
    companies = Corporate.list_companies()
    open_count = Analytics.count_open_anomalies()

    critical_count =
      Enum.count(anomalies, fn a -> a.severity == "critical" and a.status == "open" end)

    investigating_count =
      Enum.count(anomalies, fn a -> a.status == "investigating" end)

    now = DateTime.utc_now()
    month_start = %{now | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

    resolved_this_month =
      Enum.count(anomalies, fn a ->
        a.status == "resolved" and
          not is_nil(a.resolved_at) and
          DateTime.compare(a.resolved_at, month_start) in [:gt, :eq]
      end)

    {:ok,
     assign(socket,
       page_title: "Anomaly Detection",
       anomalies: anomalies,
       companies: companies,
       open_count: open_count,
       critical_count: critical_count,
       investigating_count: investigating_count,
       resolved_this_month: resolved_this_month,
       filter_status: "",
       filter_severity: "",
       filter_anomaly_type: "",
       filter_entity_type: "",
       show_notes_for: nil,
       notes_text: "",
       running_detection: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter", params, socket) do
    opts = [
      status: params["status"],
      severity: params["severity"],
      anomaly_type: params["anomaly_type"],
      entity_type: params["entity_type"]
    ]

    anomalies = Analytics.list_anomalies(opts)

    {:noreply,
     assign(socket,
       anomalies: anomalies,
       filter_status: params["status"] || "",
       filter_severity: params["severity"] || "",
       filter_anomaly_type: params["anomaly_type"] || "",
       filter_entity_type: params["entity_type"] || ""
     )}
  end

  # Permission gating
  def handle_event("run_detection", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("investigate", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("resolve", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("mark_false_positive", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("run_detection", _params, socket) do
    Analytics.detect_transaction_anomalies()
    Analytics.detect_financial_anomalies()

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Anomaly detection completed")}
  end

  def handle_event("investigate", %{"id" => id}, socket) do
    anomaly = Analytics.get_anomaly!(String.to_integer(id))

    case Analytics.update_anomaly(anomaly, %{status: "investigating"}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Anomaly marked as investigating")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update anomaly")}
    end
  end

  def handle_event("show_notes", %{"id" => id}, socket) do
    {:noreply, assign(socket, show_notes_for: String.to_integer(id), notes_text: "")}
  end

  def handle_event("close_notes", _, socket) do
    {:noreply, assign(socket, show_notes_for: nil, notes_text: "")}
  end

  def handle_event("resolve", %{"id" => id, "notes" => notes}, socket) do
    anomaly = Analytics.get_anomaly!(String.to_integer(id))
    user_id = socket.assigns.current_scope.user.id

    case Analytics.resolve_anomaly(anomaly, user_id, notes) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> assign(show_notes_for: nil)
         |> put_flash(:info, "Anomaly resolved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to resolve anomaly")}
    end
  end

  def handle_event("mark_false_positive", %{"id" => id, "notes" => notes}, socket) do
    anomaly = Analytics.get_anomaly!(String.to_integer(id))
    user_id = socket.assigns.current_scope.user.id

    case Analytics.mark_false_positive(anomaly, user_id, notes) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> assign(show_notes_for: nil)
         |> put_flash(:info, "Anomaly marked as false positive")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update anomaly")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    opts = [
      status: socket.assigns.filter_status,
      severity: socket.assigns.filter_severity,
      anomaly_type: socket.assigns.filter_anomaly_type,
      entity_type: socket.assigns.filter_entity_type
    ]

    anomalies = Analytics.list_anomalies(opts)
    open_count = Analytics.count_open_anomalies()

    critical_count =
      Enum.count(anomalies, fn a -> a.severity == "critical" and a.status == "open" end)

    investigating_count =
      Enum.count(anomalies, fn a -> a.status == "investigating" end)

    assign(socket,
      anomalies: anomalies,
      open_count: open_count,
      critical_count: critical_count,
      investigating_count: investigating_count
    )
  end

  defp severity_tag("low"), do: "tag-ink"
  defp severity_tag("medium"), do: "tag-lemon"
  defp severity_tag("high"), do: "tag-crimson"
  defp severity_tag("critical"), do: "tag-crimson"
  defp severity_tag(_), do: "tag-ink"

  defp status_tag("open"), do: "tag-lemon"
  defp status_tag("investigating"), do: "tag-jade"
  defp status_tag("resolved"), do: "tag-ink"
  defp status_tag("false_positive"), do: "tag-ink"
  defp status_tag(_), do: "tag-ink"

  defp format_decimal(nil), do: "---"
  defp format_decimal(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_decimal(v), do: to_string(v)

  defp severity_distribution(anomalies) do
    anomalies
    |> Enum.group_by(& &1.severity)
    |> Enum.sort_by(fn {sev, _} ->
      case sev do
        "critical" -> 0
        "high" -> 1
        "medium" -> 2
        "low" -> 3
        _ -> 4
      end
    end)
  end

  defp avg_resolution_time(anomalies) do
    resolved =
      anomalies
      |> Enum.filter(fn a -> a.status == "resolved" && a.resolved_at && a.inserted_at end)
      |> Enum.map(fn a ->
        DateTime.diff(a.resolved_at, a.inserted_at, :hour)
      end)

    if resolved != [] do
      avg_hours = Enum.sum(resolved) / length(resolved)

      cond do
        avg_hours < 24 -> "#{Float.round(avg_hours, 1)}h"
        true -> "#{Float.round(avg_hours / 24, 1)}d"
      end
    else
      "N/A"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Anomaly Detection</h1>
          <p class="deck">Automated detection of unusual patterns in transactions and financials</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="run_detection">
            Run Detection
          </button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Open Anomalies</div>
        <div class={"metric-value #{if @open_count > 0, do: "num-negative", else: ""}"}>{@open_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Critical</div>
        <div class={"metric-value #{if @critical_count > 0, do: "num-negative", else: ""}"}>{@critical_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Investigating</div>
        <div class="metric-value">{@investigating_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Resolved This Month</div>
        <div class="metric-value num-positive">{@resolved_this_month}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Avg Resolution Time</div>
        <div class="metric-value">{avg_resolution_time(@anomalies)}</div>
      </div>
    </div>

    <%!-- Severity Distribution --%>
    <div class="section">
      <div class="section-head"><h2>Severity Distribution</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Severity</th>
              <th class="th-num">Count</th>
              <th class="th-num">Open</th>
            </tr>
          </thead>
          <tbody>
            <%= for {sev, items} <- severity_distribution(@anomalies) do %>
              <tr>
                <td><span class={"tag #{severity_tag(sev)}"}>{sev}</span></td>
                <td class="td-num">{length(items)}</td>
                <td class="td-num">{Enum.count(items, &(&1.status in ["open", "investigating"]))}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Filter</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <form phx-change="filter" style="display: flex; gap: 1rem; flex-wrap: wrap; align-items: flex-end;">
          <div class="form-group" style="margin: 0;">
            <label class="form-label">Status</label>
            <select name="status" class="form-select" style="width: auto;">
              <option value="">All</option>
              <%= for s <- ~w(open investigating resolved false_positive) do %>
                <option value={s} selected={@filter_status == s}>{s}</option>
              <% end %>
            </select>
          </div>
          <div class="form-group" style="margin: 0;">
            <label class="form-label">Severity</label>
            <select name="severity" class="form-select" style="width: auto;">
              <option value="">All</option>
              <%= for s <- ~w(low medium high critical) do %>
                <option value={s} selected={@filter_severity == s}>{s}</option>
              <% end %>
            </select>
          </div>
          <div class="form-group" style="margin: 0;">
            <label class="form-label">Anomaly Type</label>
            <select name="anomaly_type" class="form-select" style="width: auto;">
              <option value="">All</option>
              <%= for t <- ~w(outlier duplicate unusual_amount unusual_frequency rapid_change) do %>
                <option value={t} selected={@filter_anomaly_type == t}>{t}</option>
              <% end %>
            </select>
          </div>
          <div class="form-group" style="margin: 0;">
            <label class="form-label">Entity Type</label>
            <select name="entity_type" class="form-select" style="width: auto;">
              <option value="">All</option>
              <%= for t <- ~w(transaction financial holding bank_account) do %>
                <option value={t} selected={@filter_entity_type == t}>{t}</option>
              <% end %>
            </select>
          </div>
        </form>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Anomalies</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Description</th>
              <th>Entity</th>
              <th>Type</th>
              <th>Severity</th>
              <th class="th-num">Detected</th>
              <th class="th-num">Expected Range</th>
              <th class="th-num">Deviation %</th>
              <th>Status</th>
              <th>Created</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for anomaly <- @anomalies do %>
              <tr>
                <td>{anomaly.description || "---"}</td>
                <td><span class="tag tag-ink">{anomaly.entity_type}</span> #{anomaly.entity_id || ""}</td>
                <td><span class="tag tag-ink">{anomaly.anomaly_type}</span></td>
                <td><span class={"tag #{severity_tag(anomaly.severity)}"}>{anomaly.severity}</span></td>
                <td class="td-num">{format_decimal(anomaly.detected_value)}</td>
                <td class="td-num">
                  <%= if anomaly.expected_range_low || anomaly.expected_range_high do %>
                    {format_decimal(anomaly.expected_range_low)} - {format_decimal(anomaly.expected_range_high)}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{format_decimal(anomaly.deviation_pct)}</td>
                <td><span class={"tag #{status_tag(anomaly.status)}"}>{anomaly.status}</span></td>
                <td class="td-mono">{Calendar.strftime(anomaly.inserted_at, "%Y-%m-%d")}</td>
                <td>
                  <%= if @can_write and anomaly.status in ["open", "investigating"] do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <%= if anomaly.status == "open" do %>
                        <button phx-click="investigate" phx-value-id={anomaly.id} class="btn btn-secondary btn-sm">Investigate</button>
                      <% end %>
                      <button phx-click="show_notes" phx-value-id={anomaly.id} class="btn btn-primary btn-sm">Resolve</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @anomalies == [] do %>
          <div class="empty-state">
            <p>No anomalies found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Run the detection engine to scan transactions and financials for unusual patterns.
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--rule);">
      <span style="font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint);">Related</span>
      <div style="display: flex; gap: 1rem; margin-top: 0.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/alerts"} class="td-link" style="font-size: 0.85rem;">Alerts</.link>
        <.link navigate={~p"/audit-log"} class="td-link" style="font-size: 0.85rem;">Audit Log</.link>
      </div>
    </div>

    <%!-- Resolve / False Positive Modal --%>
    <%= if @show_notes_for do %>
      <div class="dialog-overlay" phx-click="close_notes">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Resolve Anomaly</h3>
          </div>
          <div class="dialog-body">
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea id="resolve-notes" class="form-input" rows="3" placeholder="Add resolution notes..."></textarea>
            </div>
            <div class="form-actions" style="display: flex; gap: 0.5rem;">
              <button
                class="btn btn-primary"
                phx-click="resolve"
                phx-value-id={@show_notes_for}
                phx-value-notes=""
              >
                Resolve
              </button>
              <button
                class="btn btn-secondary"
                phx-click="mark_false_positive"
                phx-value-id={@show_notes_for}
                phx-value-notes=""
              >
                False Positive
              </button>
              <button class="btn btn-secondary" phx-click="close_notes">Cancel</button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
