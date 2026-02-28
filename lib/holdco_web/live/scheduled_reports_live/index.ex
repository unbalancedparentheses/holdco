defmodule HoldcoWeb.ScheduledReportsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}
  alias Holdco.Analytics.ScheduledReport

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    {:ok,
     assign(socket,
       page_title: "Scheduled Reports",
       reports: Analytics.list_scheduled_reports(),
       companies: Corporate.list_companies(),
       show_form: false,
       editing_report: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: true, editing_report: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_report: report)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_report: nil)}
  end

  def handle_event("save_report", %{"report" => params}, socket) do
    case socket.assigns.editing_report do
      nil ->
        case Analytics.create_scheduled_report(params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> reload()
             |> put_flash(:info, "Scheduled report created")
             |> assign(show_form: false)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create report")}
        end

      report ->
        case Analytics.update_scheduled_report(report, params) do
          {:ok, _} ->
            {:noreply,
             socket
             |> reload()
             |> put_flash(:info, "Scheduled report updated")
             |> assign(show_form: false, editing_report: nil)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update report")}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))

    case Analytics.delete_scheduled_report(report) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Report deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete report")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))

    case Analytics.update_scheduled_report(report, %{is_active: !report.is_active}) do
      {:ok, _} ->
        status = if report.is_active, do: "paused", else: "activated"
        {:noreply, reload(socket) |> put_flash(:info, "Report #{status}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle report")}
    end
  end

  def handle_event("send_now", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))

    case Oban.insert(Holdco.Workers.ScheduledReportWorker.new(%{"report_id" => report.id})) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Report '#{report.name}' queued for immediate delivery")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to queue report")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    assign(socket, reports: Analytics.list_scheduled_reports())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Scheduled Reports</h1>
      <p class="deck">
        Configure automated report delivery by email
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Reports</h2>
        <span class="count">{length(@reports)} configured</span>
        <button class="btn btn-sm btn-primary" phx-click="show_form">New Report</button>
      </div>

      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Frequency</th>
              <th>Recipients</th>
              <th>Format</th>
              <th>Next Run</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @reports do %>
              <tr>
                <td class="td-name">{r.name}</td>
                <td><span class="tag tag-ink">{format_type(r.report_type)}</span></td>
                <td>{r.frequency}</td>
                <td class="td-mono" style="max-width: 200px; overflow: hidden; text-overflow: ellipsis;">
                  {r.recipients}
                </td>
                <td>{r.format}</td>
                <td class="td-mono">{r.next_run_date || "Not set"}</td>
                <td>
                  <button
                    phx-click="toggle_active"
                    phx-value-id={r.id}
                    class={"tag #{if r.is_active, do: "tag-green", else: "tag-red"}"}
                    style="cursor: pointer; border: none;"
                  >
                    {if r.is_active, do: "Active", else: "Paused"}
                  </button>
                </td>
                <td style="white-space: nowrap;">
                  <button phx-click="send_now" phx-value-id={r.id} class="btn btn-sm btn-secondary">
                    Send Now
                  </button>
                  <button phx-click="edit" phx-value-id={r.id} class="btn btn-sm btn-secondary">
                    Edit
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={r.id}
                    class="btn btn-danger btn-sm"
                    data-confirm="Delete this scheduled report?"
                  >
                    Del
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @reports == [] do %>
          <div class="empty-state">
            No scheduled reports configured yet. Create one to automate report delivery.
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @editing_report, do: "Edit Report", else: "New Scheduled Report"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_report">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="report[name]"
                  class="form-input"
                  value={if @editing_report, do: @editing_report.name}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Report Type *</label>
                <select name="report[report_type]" class="form-select" required>
                  <option value="">Select type...</option>
                  <%= for rt <- ScheduledReport.report_types() do %>
                    <option
                      value={rt}
                      selected={@editing_report && @editing_report.report_type == rt}
                    >
                      {format_type(rt)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Frequency *</label>
                <select name="report[frequency]" class="form-select" required>
                  <%= for f <- ScheduledReport.frequencies() do %>
                    <option
                      value={f}
                      selected={@editing_report && @editing_report.frequency == f}
                    >
                      {String.capitalize(f)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Recipients * (comma-separated emails)</label>
                <input
                  type="text"
                  name="report[recipients]"
                  class="form-input"
                  value={if @editing_report, do: @editing_report.recipients}
                  placeholder="alice@example.com, bob@example.com"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Format</label>
                <select name="report[format]" class="form-select">
                  <%= for f <- ScheduledReport.formats() do %>
                    <option
                      value={f}
                      selected={@editing_report && @editing_report.format == f}
                    >
                      {String.upcase(f)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Company (optional, for scoped reports)</label>
                <select name="report[company_id]" class="form-select">
                  <option value="">All companies</option>
                  <%= for c <- @companies do %>
                    <option
                      value={c.id}
                      selected={@editing_report && @editing_report.company_id == c.id}
                    >
                      {c.name}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Next Run Date</label>
                <input
                  type="date"
                  name="report[next_run_date]"
                  class="form-input"
                  value={if @editing_report, do: @editing_report.next_run_date, else: Date.to_iso8601(Date.utc_today())}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="report[notes]" class="form-input">{if @editing_report, do: @editing_report.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @editing_report, do: "Update", else: "Create"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_type("portfolio_summary"), do: "Portfolio Summary"
  defp format_type("financial_report"), do: "Financial Report"
  defp format_type("compliance_report"), do: "Compliance Report"
  defp format_type("board_pack"), do: "Board Pack"
  defp format_type(other), do: other
end
