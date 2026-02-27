defmodule HoldcoWeb.KpiLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    kpis = Analytics.list_kpis()
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "KPI Tracking",
       kpis: kpis,
       companies: companies,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       selected_kpi: nil,
       snapshots: [],
       show_snapshot_form: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("close_snapshot_form", _, socket),
    do: {:noreply, assign(socket, show_snapshot_form: false)}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    kpis = Analytics.list_kpis(company_id)
    {:noreply, assign(socket, selected_company_id: id, kpis: kpis)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    kpi = Analytics.get_kpi!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: kpi)}
  end

  def handle_event("select_kpi", %{"id" => id}, socket) do
    kpi_id = String.to_integer(id)
    kpi = Analytics.get_kpi!(kpi_id)
    snapshots = Analytics.list_kpi_snapshots(kpi_id)
    {:noreply, assign(socket, selected_kpi: kpi, snapshots: snapshots)}
  end

  def handle_event("deselect_kpi", _, socket) do
    {:noreply, assign(socket, selected_kpi: nil, snapshots: [])}
  end

  def handle_event("show_snapshot_form", _, socket) do
    {:noreply, assign(socket, show_snapshot_form: true)}
  end

  # Permission gating
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_snapshot", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"kpi" => params}, socket) do
    case Analytics.create_kpi(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "KPI created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create KPI")}
    end
  end

  def handle_event("update", %{"kpi" => params}, socket) do
    kpi = socket.assigns.editing_item

    case Analytics.update_kpi(kpi, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "KPI updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update KPI")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    kpi = Analytics.get_kpi!(String.to_integer(id))
    Analytics.delete_kpi(kpi)

    selected_kpi =
      if socket.assigns.selected_kpi && socket.assigns.selected_kpi.id == kpi.id,
        do: nil,
        else: socket.assigns.selected_kpi

    {:noreply,
     reload(socket)
     |> put_flash(:info, "KPI deleted")
     |> assign(selected_kpi: selected_kpi, snapshots: if(selected_kpi, do: socket.assigns.snapshots, else: []))}
  end

  def handle_event("save_snapshot", %{"snapshot" => params}, socket) do
    kpi = socket.assigns.selected_kpi
    attrs = Map.put(params, "kpi_id", kpi.id)

    case Analytics.create_kpi_snapshot(attrs) do
      {:ok, _} ->
        snapshots = Analytics.list_kpi_snapshots(kpi.id)
        updated_kpi = Analytics.get_kpi!(kpi.id)

        {:noreply,
         reload(socket)
         |> assign(
           selected_kpi: updated_kpi,
           snapshots: snapshots,
           show_snapshot_form: false
         )
         |> put_flash(:info, "Snapshot recorded")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to record snapshot")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assign(socket, kpis: Analytics.list_kpis(company_id))
  end

  defp kpi_status(kpi) do
    current = current_value(kpi)
    target = kpi.target_value
    threshold = kpi.threshold_value

    cond do
      is_nil(current) or is_nil(target) -> :unknown
      current >= target -> :green
      not is_nil(threshold) and current >= threshold -> :yellow
      true -> :red
    end
  end

  defp current_value(kpi) do
    case kpi.snapshots do
      [latest | _] -> latest.current_value
      _ -> nil
    end
  end

  defp status_tag(:green), do: "tag-jade"
  defp status_tag(:yellow), do: "tag-lemon"
  defp status_tag(:red), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"

  defp status_label(:green), do: "On Target"
  defp status_label(:yellow), do: "Warning"
  defp status_label(:red), do: "Below Threshold"
  defp status_label(_), do: "No Data"

  defp trend_indicator(kpi) do
    sorted = Enum.sort_by(kpi.snapshots || [], & &1.date)

    case Enum.take(sorted, -2) do
      [prev, curr] ->
        cond do
          curr.current_value > prev.current_value -> {"^", "num-positive"}
          curr.current_value < prev.current_value -> {"v", "num-negative"}
          true -> {"-", ""}
        end

      _ ->
        {"-", ""}
    end
  end

  defp format_value(nil, _unit), do: "---"
  defp format_value(val, "%" ), do: "#{format_number(val)}%"
  defp format_value(val, unit) when unit in [nil, ""], do: format_number(val)
  defp format_value(val, unit), do: "#{format_number(val)} #{unit}"

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp sparkline_chart_data(snapshots) do
    sorted = Enum.sort_by(snapshots, & &1.date)

    %{
      labels: Enum.map(sorted, &to_string(&1.date)),
      datasets: [
        %{
          label: "Value",
          data: Enum.map(sorted, & &1.current_value),
          borderColor: "#4a8c87",
          backgroundColor: "rgba(74, 140, 135, 0.1)",
          fill: true,
          tension: 0.3,
          pointRadius: 3
        }
      ]
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>KPI Tracking</h1>
          <p class="deck">Monitor key performance indicators across all entities</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Companies</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add KPI</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <% green_count = Enum.count(@kpis, &(kpi_status(&1) == :green)) %>
    <% yellow_count = Enum.count(@kpis, &(kpi_status(&1) == :yellow)) %>
    <% red_count = Enum.count(@kpis, &(kpi_status(&1) == :red)) %>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total KPIs</div>
        <div class="metric-value">{length(@kpis)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">On Target</div>
        <div class="metric-value num-positive">{green_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Warning</div>
        <div class="metric-value">{yellow_count}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Below Threshold</div>
        <div class="metric-value num-negative">{red_count}</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>KPIs</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Company</th>
                <th class="th-num">Current</th>
                <th class="th-num">Target</th>
                <th>Status</th>
                <th>Trend</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for kpi <- @kpis do %>
                <% status = kpi_status(kpi) %>
                <% current = current_value(kpi) %>
                <% {trend_sym, trend_class} = trend_indicator(kpi) %>
                <tr>
                  <td>
                    <a href="#" phx-click="select_kpi" phx-value-id={kpi.id} class="td-link td-name">
                      {kpi.name}
                    </a>
                  </td>
                  <td><span class="tag tag-ink">{kpi.metric_type}</span></td>
                  <td>
                    <%= if kpi.company do %>
                      <.link navigate={~p"/companies/#{kpi.company.id}"} class="td-link">{kpi.company.name}</.link>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td class="td-num">{format_value(current, kpi.unit)}</td>
                  <td class="td-num">{format_value(kpi.target_value, kpi.unit)}</td>
                  <td><span class={"tag #{status_tag(status)}"}>{status_label(status)}</span></td>
                  <td class={"td-num #{trend_class}"}>{trend_sym}</td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit" phx-value-id={kpi.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete" phx-value-id={kpi.id} class="btn btn-danger btn-sm" data-confirm="Delete this KPI?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @kpis == [] do %>
            <div class="empty-state">
              <p>No KPIs defined yet.</p>
              <p style="color: var(--muted); font-size: 0.9rem;">
                Define key performance indicators to track metrics like revenue growth, customer count, or expense ratios across your entities.
              </p>
              <%= if @can_write do %>
                <button class="btn btn-primary" phx-click="show_form">Add Your First KPI</button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>
            <%= if @selected_kpi do %>
              {@selected_kpi.name} -- Snapshots
            <% else %>
              KPI Detail
            <% end %>
          </h2>
          <%= if not is_nil(@selected_kpi) and @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_snapshot_form">Record Snapshot</button>
          <% end %>
        </div>
        <%= if @selected_kpi do %>
          <div class="panel" style="padding: 1rem;">
            <div class="metrics-strip" style="margin-bottom: 1rem;">
              <div class="metric-cell">
                <div class="metric-label">Current Value</div>
                <div class="metric-value">{format_value(current_value(@selected_kpi), @selected_kpi.unit)}</div>
              </div>
              <div class="metric-cell">
                <div class="metric-label">Target</div>
                <div class="metric-value">{format_value(@selected_kpi.target_value, @selected_kpi.unit)}</div>
              </div>
              <div class="metric-cell">
                <div class="metric-label">Threshold</div>
                <div class="metric-value">{format_value(@selected_kpi.threshold_value, @selected_kpi.unit)}</div>
              </div>
            </div>

            <%= if @snapshots != [] do %>
              <div
                id="kpi-sparkline"
                phx-hook="ChartHook"
                data-chart-type="line"
                data-chart-data={Jason.encode!(sparkline_chart_data(@snapshots))}
                data-chart-options={
                  Jason.encode!(%{
                    plugins: %{legend: %{display: false}},
                    scales: %{y: %{beginAtZero: false}}
                  })
                }
                style="height: 300px;"
              >
                <canvas></canvas>
              </div>
            <% else %>
              <div class="empty-state">No snapshots recorded yet for this KPI.</div>
            <% end %>

            <div style="margin-top: 1rem;">
              <table>
                <thead>
                  <tr>
                    <th>Date</th>
                    <th class="th-num">Value</th>
                    <th>Notes</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for snap <- @snapshots do %>
                    <tr>
                      <td class="td-mono">{snap.date}</td>
                      <td class="td-num">{format_value(snap.current_value, @selected_kpi.unit)}</td>
                      <td>{snap.trend || ""}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <div style="margin-top: 0.5rem;">
              <a href="#" phx-click="deselect_kpi" class="btn btn-secondary btn-sm">Close Detail</a>
            </div>
          </div>
        <% else %>
          <div class="panel">
            <div class="empty-state">Select a KPI from the list to view its historical snapshots and trend chart.</div>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Add/Edit KPI Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit KPI", else: "Add KPI"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="kpi[name]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Metric Type *</label>
                <select name="kpi[metric_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(currency percentage count ratio) do %>
                    <option value={t} selected={@editing_item && @editing_item.metric_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Target Value *</label>
                <input
                  type="number"
                  name="kpi[target_value]"
                  class="form-input"
                  step="any"
                  value={if @editing_item, do: @editing_item.target_value, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Threshold Value</label>
                <input
                  type="number"
                  name="kpi[threshold_value]"
                  class="form-input"
                  step="any"
                  value={if @editing_item, do: @editing_item.threshold_value, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Unit</label>
                <input
                  type="text"
                  name="kpi[unit]"
                  class="form-input"
                  placeholder="e.g. %, USD, users"
                  value={if @editing_item, do: @editing_item.unit, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="kpi[company_id]" class="form-select">
                  <option value="">-- No company (global) --</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update KPI", else: "Add KPI"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- Record Snapshot Modal --%>
    <%= if @show_snapshot_form and @selected_kpi do %>
      <div class="dialog-overlay" phx-click="close_snapshot_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Record Snapshot for {@selected_kpi.name}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_snapshot">
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="date"
                  name="snapshot[date]"
                  class="form-input"
                  value={Date.utc_today()}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Value *</label>
                <input
                  type="number"
                  name="snapshot[current_value]"
                  class="form-input"
                  step="any"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="snapshot[notes]" class="form-input"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Record Snapshot</button>
                <button type="button" phx-click="close_snapshot_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
