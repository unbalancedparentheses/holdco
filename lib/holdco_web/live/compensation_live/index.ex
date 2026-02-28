defmodule HoldcoWeb.CompensationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Finance
  alias Holdco.Finance.CompensationRecord

  @impl true
  def mount(_params, _session, socket) do
    companies = Holdco.Corporate.list_companies()
    records = Finance.list_compensation_records()

    {:ok,
     assign(socket,
       page_title: "Compensation",
       companies: companies,
       records: records,
       total_comp: nil,
       by_department: [],
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    records = Finance.list_compensation_records(company_id)
    total_comp = if company_id, do: Finance.total_compensation(company_id), else: nil
    by_dept = if company_id, do: Finance.compensation_by_department(company_id), else: []
    {:noreply, assign(socket, selected_company_id: id, records: records, total_comp: total_comp, by_department: by_dept)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    record = Finance.get_compensation_record!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: record)}
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

  def handle_event("save", %{"compensation_record" => params}, socket) do
    case Finance.create_compensation_record(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Compensation record added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add compensation record")}
    end
  end

  def handle_event("update", %{"compensation_record" => params}, socket) do
    record = socket.assigns.editing_item

    case Finance.update_compensation_record(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Compensation record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update compensation record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Finance.get_compensation_record!(String.to_integer(id))

    case Finance.delete_compensation_record(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Compensation record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete compensation record")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Payroll & Compensation</h1>
          <p class="deck">Track employee compensation, bonuses, and benefits</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Record</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@records)}</div>
      </div>
      <%= if @total_comp do %>
        <div class="metric-cell">
          <div class="metric-label">Total Active Compensation</div>
          <div class="metric-value">${format_number(@total_comp)}</div>
        </div>
      <% end %>
    </div>

    <%= if @by_department != [] do %>
      <div class="section">
        <div class="section-head"><h2>By Department</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Department</th><th class="th-num">Employees</th><th class="th-num">Total Amount</th></tr>
            </thead>
            <tbody>
              <%= for row <- @by_department do %>
                <tr>
                  <td>{row.department || "Unassigned"}</td>
                  <td class="td-num">{row.count}</td>
                  <td class="td-num">${format_number(row.total_amount)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Compensation Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Employee</th><th>Role</th><th>Department</th><th>Type</th>
              <th class="th-num">Amount</th><th>Frequency</th><th>Status</th><th>Effective</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for cr <- @records do %>
              <tr>
                <td class="td-name">{cr.employee_name}</td>
                <td>{cr.role || "---"}</td>
                <td>{cr.department || "---"}</td>
                <td><span class="tag tag-sky">{humanize(cr.compensation_type)}</span></td>
                <td class="td-num">{cr.currency} {format_number(cr.amount)}</td>
                <td>{humanize(cr.frequency)}</td>
                <td><span class={"tag #{comp_status_tag(cr.status)}"}>{humanize(cr.status)}</span></td>
                <td class="td-mono">{cr.effective_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={cr.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={cr.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @records == [] do %>
          <div class="empty-state">
            <p>No compensation records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Record", else: "Add Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="compensation_record[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Employee Name *</label>
                <input type="text" name="compensation_record[employee_name]" class="form-input" value={if @editing_item, do: @editing_item.employee_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Role</label>
                <input type="text" name="compensation_record[role]" class="form-input" value={if @editing_item, do: @editing_item.role, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Department</label>
                <input type="text" name="compensation_record[department]" class="form-input" value={if @editing_item, do: @editing_item.department, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="compensation_record[compensation_type]" class="form-select" required>
                  <%= for t <- CompensationRecord.compensation_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.compensation_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="compensation_record[amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="compensation_record[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Frequency *</label>
                <select name="compensation_record[frequency]" class="form-select" required>
                  <%= for f <- CompensationRecord.frequencies() do %>
                    <option value={f} selected={@editing_item && @editing_item.frequency == f}>{humanize(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Effective Date</label>
                <input type="date" name="compensation_record[effective_date]" class="form-input" value={if @editing_item, do: @editing_item.effective_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input type="date" name="compensation_record[end_date]" class="form-input" value={if @editing_item, do: @editing_item.end_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Vesting Schedule</label>
                <input type="text" name="compensation_record[vesting_schedule]" class="form-input" value={if @editing_item, do: @editing_item.vesting_schedule, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="compensation_record[status]" class="form-select">
                  <%= for s <- CompensationRecord.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="compensation_record[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Record"}</button>
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
    company_id = case socket.assigns.selected_company_id do
      "" -> nil
      id -> String.to_integer(id)
    end

    records = Finance.list_compensation_records(company_id)
    total_comp = if company_id, do: Finance.total_compensation(company_id), else: nil
    by_dept = if company_id, do: Finance.compensation_by_department(company_id), else: []
    assign(socket, records: records, total_comp: total_comp, by_department: by_dept)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp comp_status_tag("active"), do: "tag-jade"
  defp comp_status_tag("pending"), do: "tag-lemon"
  defp comp_status_tag("terminated"), do: "tag-rose"
  defp comp_status_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "---"
end
