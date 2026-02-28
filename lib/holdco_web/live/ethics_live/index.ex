defmodule HoldcoWeb.EthicsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Governance, Corporate}
  alias Holdco.Governance.EthicsReport

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    reports = Governance.list_ethics_reports()
    summary = Governance.ethics_summary()

    {:ok,
     assign(socket,
       page_title: "Whistleblower & Ethics Channel",
       companies: companies,
       reports: reports,
       summary: summary,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    report = Governance.get_ethics_report!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: report)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"ethics_report" => params}, socket) do
    case Governance.create_ethics_report(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Ethics report created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create ethics report")}
    end
  end

  def handle_event("update", %{"ethics_report" => params}, socket) do
    report = socket.assigns.editing_item

    case Governance.update_ethics_report(report, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Ethics report updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update ethics report")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    report = Governance.get_ethics_report!(String.to_integer(id))

    case Governance.delete_ethics_report(report) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Ethics report deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete ethics report")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Whistleblower & Ethics Channel</h1>
          <p class="deck">Report, investigate, and resolve ethics complaints</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Report</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Reports</div>
        <div class="metric-value">{length(@reports)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Open</div>
        <div class="metric-value num-negative">{Enum.count(@reports, &(&1.status in ["received", "under_investigation", "escalated"]))}</div>
      </div>
      <%= for s <- @summary.by_severity do %>
        <div class="metric-cell">
          <div class="metric-label">{humanize(s.severity)}</div>
          <div class="metric-value">{s.count}</div>
        </div>
      <% end %>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Ethics Reports</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Type</th><th>Severity</th><th>Reporter</th>
              <th>Status</th><th>Investigator</th><th>Reported</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @reports do %>
              <tr>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize(r.report_type)}</span></td>
                <td><span class={"tag #{severity_tag(r.severity)}"}>{humanize(r.severity)}</span></td>
                <td>{humanize(r.reporter_type)}</td>
                <td><span class={"tag #{ethics_status_tag(r.status)}"}>{humanize(r.status)}</span></td>
                <td>{r.assigned_investigator || "---"}</td>
                <td class="td-mono">{r.reported_date}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={r.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete this report?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @reports == [] do %>
          <div class="empty-state">
            <p>No ethics reports found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">File Your First Report</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Ethics Report", else: "New Ethics Report"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="ethics_report[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Report Type *</label>
                <select name="ethics_report[report_type]" class="form-select" required>
                  <%= for t <- EthicsReport.report_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.report_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Reporter Type *</label>
                <select name="ethics_report[reporter_type]" class="form-select" required>
                  <%= for t <- EthicsReport.reporter_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.reporter_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Reporter Name</label>
                <input type="text" name="ethics_report[reporter_name]" class="form-input" value={if @editing_item, do: @editing_item.reporter_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Severity *</label>
                <select name="ethics_report[severity]" class="form-select" required>
                  <%= for s <- EthicsReport.severities() do %>
                    <option value={s} selected={@editing_item && @editing_item.severity == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description *</label>
                <textarea name="ethics_report[description]" class="form-input" required>{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Involved Parties</label>
                <input type="text" name="ethics_report[involved_parties]" class="form-input" value={if @editing_item, do: @editing_item.involved_parties, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="ethics_report[status]" class="form-select">
                  <%= for s <- EthicsReport.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Assigned Investigator</label>
                <input type="text" name="ethics_report[assigned_investigator]" class="form-input" value={if @editing_item, do: @editing_item.assigned_investigator, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Reported Date *</label>
                <input type="date" name="ethics_report[reported_date]" class="form-input" value={if @editing_item, do: @editing_item.reported_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Investigation Notes</label>
                <textarea name="ethics_report[investigation_notes]" class="form-input">{if @editing_item, do: @editing_item.investigation_notes, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Resolution</label>
                <textarea name="ethics_report[resolution]" class="form-input">{if @editing_item, do: @editing_item.resolution, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="ethics_report[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Report", else: "Submit Report"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload(socket) do
    reports = Governance.list_ethics_reports()
    summary = Governance.ethics_summary()
    assign(socket, reports: reports, summary: summary)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp severity_tag("low"), do: "tag-jade"
  defp severity_tag("medium"), do: "tag-lemon"
  defp severity_tag("high"), do: "tag-rose"
  defp severity_tag("critical"), do: "tag-rose"
  defp severity_tag(_), do: ""

  defp ethics_status_tag("received"), do: "tag-lemon"
  defp ethics_status_tag("under_investigation"), do: "tag-sky"
  defp ethics_status_tag("escalated"), do: "tag-rose"
  defp ethics_status_tag("resolved"), do: "tag-jade"
  defp ethics_status_tag("dismissed"), do: ""
  defp ethics_status_tag(_), do: ""
end
