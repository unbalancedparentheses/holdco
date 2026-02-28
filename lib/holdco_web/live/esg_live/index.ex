defmodule HoldcoWeb.EsgLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.EsgReport

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    reports = Compliance.list_esg_reports()

    {:ok,
     assign(socket,
       page_title: "ESG Reporting",
       companies: companies,
       reports: reports,
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
    report = Compliance.get_esg_report!(String.to_integer(id))
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

  def handle_event("save", %{"esg_report" => params}, socket) do
    case Compliance.create_esg_report(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "ESG report created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create ESG report")}
    end
  end

  def handle_event("update", %{"esg_report" => params}, socket) do
    report = socket.assigns.editing_item

    case Compliance.update_esg_report(report, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "ESG report updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update ESG report")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    report = Compliance.get_esg_report!(String.to_integer(id))

    case Compliance.delete_esg_report(report) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "ESG report deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete ESG report")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>ESG Reporting</h1>
          <p class="deck">GRI, SASB, TCFD frameworks and ESG score tracking</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Report</button>
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
        <div class="metric-label">Published</div>
        <div class="metric-value">{Enum.count(@reports, &(&1.status == "published"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Draft</div>
        <div class="metric-value">{Enum.count(@reports, &(&1.status == "draft"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All ESG Reports</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Title</th><th>Framework</th><th>Period</th>
              <th>Score</th><th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @reports do %>
              <tr>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td class="td-name">{r.title}</td>
                <td><span class="tag tag-sky">{String.upcase(r.framework)}</span></td>
                <td class="td-mono">{r.reporting_period_start} to {r.reporting_period_end}</td>
                <td class="td-num">{if r.score, do: Decimal.to_string(r.score), else: "---"}</td>
                <td><span class={"tag #{status_tag(r.status)}"}>{humanize(r.status)}</span></td>
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
            <p>No ESG reports found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Report</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit ESG Report", else: "Add ESG Report"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="esg_report[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="esg_report[title]" class="form-input" value={if @editing_item, do: @editing_item.title, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Framework *</label>
                <select name="esg_report[framework]" class="form-select" required>
                  <%= for f <- EsgReport.frameworks() do %>
                    <option value={f} selected={@editing_item && @editing_item.framework == f}>{String.upcase(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Period Start *</label>
                <input type="date" name="esg_report[reporting_period_start]" class="form-input" value={if @editing_item, do: @editing_item.reporting_period_start, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Period End *</label>
                <input type="date" name="esg_report[reporting_period_end]" class="form-input" value={if @editing_item, do: @editing_item.reporting_period_end, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Score</label>
                <input type="number" name="esg_report[score]" class="form-input" step="0.01" value={if @editing_item && @editing_item.score, do: Decimal.to_string(@editing_item.score), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="esg_report[status]" class="form-select">
                  <%= for s <- EsgReport.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Published Date</label>
                <input type="date" name="esg_report[published_date]" class="form-input" value={if @editing_item, do: @editing_item.published_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="esg_report[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Report", else: "Add Report"}</button>
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
    assign(socket, reports: Compliance.list_esg_reports())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("draft"), do: "tag-lemon"
  defp status_tag("under_review"), do: "tag-sky"
  defp status_tag("published"), do: "tag-jade"
  defp status_tag(_), do: ""
end
